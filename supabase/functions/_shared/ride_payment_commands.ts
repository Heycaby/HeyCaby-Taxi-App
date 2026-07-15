import { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import {
  cancelMolliePayment,
  createMolliePaymentRoute,
  createMollieRefund,
  parseJsonConfig,
} from "./ride_payment_service.ts";

export type RidePaymentCommand =
  | "route_completed"
  | "refund_full"
  | "refund_partial"
  | "capture_cancellation_fee"
  | "capture_no_show_fee"
  | "reverse_driver_routing"
  | "void_unrouted";

export type CommandActor = {
  id: string;
  type: "admin" | "driver" | "system";
  reason?: string;
  source: string;
};

type PaymentRow = {
  id: string;
  ride_id: string;
  provider_payment_id: string | null;
  state: string;
  amount_cents: number;
  refunded_cents: number;
  driver_route_cents: number;
  currency: string;
  destination_organization_id: string | null;
  correlation_id: string;
};

type RideRow = {
  id: string;
  status: string;
  cancelled_by: string | null;
  cancellation_reason: string | null;
  cancelled_at: string | null;
  scheduled_pickup_at: string | null;
};

export function refundPolicyAmounts(input: {
  amountCents: number;
  refundedCents: number;
  retainedFeeBps: number;
}): { refundableCents: number; retainedFeeCents: number } {
  const remaining = Math.max(0, input.amountCents - input.refundedCents);
  const bps = Math.max(0, Math.min(10000, Math.trunc(input.retainedFeeBps)));
  const retainedFeeCents = Math.min(
    remaining,
    Math.round(input.amountCents * bps / 10000),
  );
  return { refundableCents: remaining - retainedFeeCents, retainedFeeCents };
}

export function routingReversalPlan(input: {
  paymentAmountCents: number;
  previouslyRefundedCents: number;
  refundAmountCents: number;
  routeAmountCents: number;
  alreadyReversedCents: number;
}): { reverseRouting: boolean; routingReversalCents: number } {
  const reverseRouting = input.previouslyRefundedCents === 0 &&
    input.refundAmountCents === input.paymentAmountCents;
  return {
    reverseRouting,
    routingReversalCents: Math.min(
      Math.max(0, input.refundAmountCents),
      Math.max(0, input.routeAmountCents - input.alreadyReversedCents),
    ),
  };
}

async function capabilityEnabled(admin: SupabaseClient): Promise<boolean> {
  const [{ data: flagsRow }, { data: health }] = await Promise.all([
    admin.from("app_config").select("value").eq("key", "feature_flags")
      .maybeSingle(),
    admin.from("mollie_marketplace_health")
      .select("routing_capability_confirmed").eq("singleton", true)
      .maybeSingle(),
  ]);
  return parseJsonConfig(flagsRow?.value).mollie_marketplace_routing_enabled ===
      true && health?.routing_capability_confirmed === true;
}

async function paymentForRide(
  admin: SupabaseClient,
  rideId: string,
): Promise<PaymentRow | null> {
  const { data, error } = await admin.from("ride_payments").select(
    "id, ride_id, provider_payment_id, state, amount_cents, refunded_cents, " +
      "driver_route_cents, currency, destination_organization_id, correlation_id",
  ).eq("ride_id", rideId).order("created_at", { ascending: false }).limit(1)
    .maybeSingle();
  if (error) throw error;
  return data as PaymentRow | null;
}

async function rideForId(
  admin: SupabaseClient,
  rideId: string,
): Promise<RideRow | null> {
  const { data, error } = await admin.from("ride_requests")
    .select(
      "id, status, cancelled_by, cancellation_reason, cancelled_at, scheduled_pickup_at",
    )
    .eq("id", rideId).maybeSingle();
  if (error) throw error;
  return data as RideRow | null;
}

async function audit(
  admin: SupabaseClient,
  payment: PaymentRow,
  actor: CommandActor,
  event: string,
  metadata: Record<string, unknown>,
) {
  await admin.from("ride_audit_log").insert({
    ride_id: payment.ride_id,
    event,
    actor_id: actor.id,
    actor_type: actor.type,
    source: actor.source,
    correlation_id: payment.correlation_id,
    metadata: {
      ride_payment_id: payment.id,
      reason: actor.reason,
      ...metadata,
    },
  });
}

async function reconcileDriverServiceFee(
  admin: SupabaseClient,
  payment: PaymentRow,
  actor: CommandActor,
) {
  const feeCollection = await admin.rpc(
    "fn_collect_prepaid_driver_service_fee",
    { p_ride_id: payment.ride_id, p_ride_payment_id: payment.id },
  );
  if (feeCollection.error || feeCollection.data?.ok !== true) {
    console.error("prepaid_driver_service_fee_collection_failed", {
      rideId: payment.ride_id,
      paymentId: payment.id,
      code: feeCollection.error?.code,
      reason: feeCollection.data?.error,
    });
    await audit(admin, payment, actor, "payment.service_fee_reconciliation_failed", {
      error: feeCollection.data?.error ?? feeCollection.error?.code ?? "unknown",
    });
  }
}

async function routeCompletedRide(
  admin: SupabaseClient,
  payment: PaymentRow,
  actor: CommandActor,
) {
  if (!await capabilityEnabled(admin)) {
    return { ok: false, error: "marketplace_routing_disabled", status: 409 };
  }
  // This RPC is the canonical evidence boundary. It returns allowed=true for
  // legacy/non-prepaid rides and while the rollout flag is disabled. Once the
  // protection flag is enabled, missing arrival, boarding, route, completion,
  // or risk evidence keeps the Mollie payment paid but unrouted.
  const { data: evidenceGate, error: evidenceGateError } = await admin.rpc(
    "fn_ride_payment_evidence_gate",
    { p_ride_id: payment.ride_id },
  );
  if (evidenceGateError) {
    console.error("ride_payment_evidence_gate_failed", {
      rideId: payment.ride_id,
      code: evidenceGateError.code,
    });
    return { ok: false, error: "payment_evidence_gate_unavailable", status: 503 };
  }
  if (evidenceGate?.allowed !== true) {
    await audit(admin, payment, actor, "payment.routing_blocked_evidence", {
      evidence_gate: evidenceGate ?? { reason: "empty_gate_response" },
    });
    return {
      ok: false,
      error: "ride_evidence_incomplete",
      status: 409,
      evidence_gate: evidenceGate,
    };
  }
  if (payment.state === "routed") {
    await reconcileDriverServiceFee(admin, payment, actor);
    return { ok: true, routed: true, idempotent_replay: true };
  }
  if (!["paid", "routing_pending", "routing_failed"].includes(payment.state)) {
    return { ok: false, error: "payment_not_routeable", status: 409 };
  }
  if (!payment.provider_payment_id) {
    return { ok: false, error: "provider_payment_id_missing", status: 409 };
  }
  if (!payment.destination_organization_id) {
    return { ok: false, error: "route_destination_missing", status: 409 };
  }
  const now = new Date().toISOString();
  if (payment.driver_route_cents <= 0) {
    await admin.from("ride_payments").update({
      state: "routed",
      routed_at: now,
      updated_at: now,
    }).eq("id", payment.id);
    await reconcileDriverServiceFee(admin, payment, actor);
    return { ok: true, routed: true, amount_cents: 0 };
  }

  let { data: route, error } = await admin.from("ride_payment_routes")
    .select("id, state, provider_route_id, idempotency_key")
    .eq("ride_payment_id", payment.id).maybeSingle();
  if (error) throw error;
  if (route?.state === "routed") {
    await admin.from("ride_payments").update({
      state: "routed",
      routed_at: now,
      updated_at: now,
    }).eq("id", payment.id);
    await reconcileDriverServiceFee(admin, payment, actor);
    return { ok: true, routed: true, idempotent_replay: true };
  }
  if (!route) {
    const { error: insertError } = await admin.from("ride_payment_routes")
      .upsert({
        id: crypto.randomUUID(),
        ride_payment_id: payment.id,
        organization_id: payment.destination_organization_id,
        amount_cents: payment.driver_route_cents,
        idempotency_key: crypto.randomUUID(),
      }, { onConflict: "ride_payment_id", ignoreDuplicates: true });
    if (insertError) throw insertError;
    const claimed = await admin.from("ride_payment_routes")
      .select("id, state, provider_route_id, idempotency_key")
      .eq("ride_payment_id", payment.id).single();
    if (claimed.error) throw claimed.error;
    route = claimed.data;
  }
  if (route.state === "routed") {
    await reconcileDriverServiceFee(admin, payment, actor);
    return { ok: true, routed: true, idempotent_replay: true };
  }
  await admin.from("ride_payments").update({
    state: "routing_pending",
    failure_code: null,
    updated_at: now,
  }).eq("id", payment.id);
  try {
    const providerRoute = await createMolliePaymentRoute({
      paymentId: payment.provider_payment_id,
      organizationId: payment.destination_organization_id,
      amountCents: payment.driver_route_cents,
      currency: payment.currency,
      idempotencyKey: route.idempotency_key,
      description: `HeyCaby Driver settlement ${payment.ride_id.slice(0, 8)}`,
    });
    await admin.from("ride_payment_routes").update({
      provider_route_id: providerRoute.id,
      state: "routed",
      provider_snapshot: providerRoute,
      updated_at: now,
    }).eq("id", route.id);
    await admin.from("ride_payments").update({
      state: "routed",
      routed_at: now,
      failure_code: null,
      updated_at: now,
    }).eq("id", payment.id);
    await admin.from("ride_payment_events").insert({
      ride_payment_id: payment.id,
      ride_id: payment.ride_id,
      event_type: "payment_routed",
      provider_event_key: `route:${providerRoute.id}`,
      from_state: "routing_pending",
      to_state: "routed",
      source: actor.source,
      actor_type: actor.type,
      actor_id: actor.id,
      correlation_id: payment.correlation_id,
      payload: {
        provider_route_id: providerRoute.id,
        organization_id: payment.destination_organization_id,
        amount_cents: payment.driver_route_cents,
      },
    });
    await audit(admin, payment, actor, "payment.prepaid_routed", {
      amount_cents: payment.driver_route_cents,
    });
    // Routing already succeeded externally. Reconciliation errors are audited
    // without retrying or duplicating the provider payout.
    await reconcileDriverServiceFee(admin, payment, actor);
    return { ok: true, routed: true };
  } catch (error) {
    await admin.from("ride_payment_routes").update({
      state: "failed",
      updated_at: now,
    }).eq("id", route.id).neq("state", "routed");
    await admin.from("ride_payments").update({
      state: "routing_failed",
      failure_code: "route_create_failed",
      updated_at: now,
    })
      .eq("id", payment.id).neq("state", "routed");
    throw error;
  }
}

async function refundRidePayment(
  admin: SupabaseClient,
  ride: RideRow,
  payment: PaymentRow,
  command: Exclude<RidePaymentCommand, "route_completed" | "void_unrouted">,
  actor: CommandActor,
) {
  if (!payment.provider_payment_id) {
    return { ok: false, error: "provider_payment_id_missing", status: 409 };
  }
  if (
    ![
      "paid",
      "routed",
      "routing_pending",
      "routing_failed",
      "partially_refunded",
    ].includes(payment.state)
  ) {
    return { ok: false, error: "payment_not_refundable", status: 409 };
  }
  const { data: configRow } = await admin.from("app_config").select("value")
    .eq("key", "ride_prepaid_payment_config").maybeSingle();
  const config = parseJsonConfig(configRow?.value);
  let retainedFeeBps = command === "capture_no_show_fee"
    ? Number(config.no_show_fee_bps ?? 0)
    : command === "refund_full" || command === "reverse_driver_routing"
    ? 0
    : Number(config.late_cancellation_fee_bps ?? 0);
  if (command === "capture_cancellation_fee") {
    const freeMinutes = Number(config.free_cancellation_minutes ?? 0);
    if (
      !Number.isInteger(freeMinutes) || freeMinutes < 0 || freeMinutes > 10080
    ) {
      return { ok: false, error: "payment_config_invalid", status: 503 };
    }
    const cancelledAt = Date.parse(ride.cancelled_at ?? "");
    const pickupAt = Date.parse(ride.scheduled_pickup_at ?? "");
    if (
      Number.isFinite(cancelledAt) && Number.isFinite(pickupAt) &&
      cancelledAt <= pickupAt - freeMinutes * 60 * 1000
    ) {
      retainedFeeBps = 0;
    }
  }
  if (
    !Number.isInteger(retainedFeeBps) || retainedFeeBps < 0 ||
    retainedFeeBps > 10000
  ) {
    return { ok: false, error: "payment_config_invalid", status: 503 };
  }
  const amounts = refundPolicyAmounts({
    amountCents: payment.amount_cents,
    refundedCents: payment.refunded_cents,
    retainedFeeBps,
  });
  if (amounts.refundableCents <= 0) {
    return {
      ok: true,
      refunded: false,
      retained_fee_cents: amounts.retainedFeeCents,
      idempotent_replay: true,
    };
  }
  const commandKey = command;
  let { data: refund, error } = await admin.from("ride_payment_refunds")
    .select("id, state, provider_refund_id, idempotency_key, amount_cents")
    .eq("ride_payment_id", payment.id).eq("command_key", commandKey)
    .maybeSingle();
  if (error) throw error;
  if (refund) {
    return { ok: true, refund, idempotent_replay: true };
  }
  const { data: route, error: routeError } = await admin.from(
    "ride_payment_routes",
  )
    .select("state, amount_cents, organization_id")
    .eq("ride_payment_id", payment.id).maybeSingle();
  if (routeError) throw routeError;
  const routed = route?.state === "routed";
  const { data: priorReversals, error: priorReversalsError } = await admin
    .from("ride_payment_refunds").select("routing_reversal_cents")
    .eq("ride_payment_id", payment.id).eq("state", "refunded");
  if (priorReversalsError) throw priorReversalsError;
  const alreadyReversedCents = (priorReversals ?? []).reduce(
    (sum, row) => sum + Number(row.routing_reversal_cents ?? 0),
    0,
  );
  const reversalPlan = routed
    ? routingReversalPlan({
      paymentAmountCents: payment.amount_cents,
      previouslyRefundedCents: payment.refunded_cents,
      refundAmountCents: amounts.refundableCents,
      routeAmountCents: Number(route.amount_cents),
      alreadyReversedCents,
    })
    : { reverseRouting: false, routingReversalCents: 0 };
  const routingReversalCents = reversalPlan.routingReversalCents;
  const idempotencyKey = crypto.randomUUID();
  const candidateId = crypto.randomUUID();
  const { error: insertError } = await admin.from("ride_payment_refunds")
    .insert({
      id: candidateId,
      ride_payment_id: payment.id,
      amount_cents: amounts.refundableCents,
      state: "creating",
      reason_code: command,
      command_key: commandKey,
      admin_reason: actor.reason,
      routing_reversal_cents: routingReversalCents,
      policy_snapshot: {
        retained_fee_bps: retainedFeeBps,
        retained_fee_cents: amounts.retainedFeeCents,
      },
      idempotency_key: idempotencyKey,
      requested_by: actor.id,
    });
  if (insertError?.code === "23505") {
    const existing = await admin.from("ride_payment_refunds")
      .select("id, state, provider_refund_id, idempotency_key, amount_cents")
      .eq("ride_payment_id", payment.id).eq("command_key", commandKey).single();
    if (existing.error) throw existing.error;
    return { ok: true, refund: existing.data, idempotent_replay: true };
  }
  if (insertError) throw insertError;
  refund = {
    id: candidateId,
    state: "creating",
    provider_refund_id: null,
    idempotency_key: idempotencyKey,
    amount_cents: amounts.refundableCents,
  };
  try {
    const providerRefund = await createMollieRefund({
      paymentId: payment.provider_payment_id,
      amountCents: amounts.refundableCents,
      currency: payment.currency,
      description: `HeyCaby ${command.replaceAll("_", " ")} ${
        payment.ride_id.slice(0, 8)
      }`,
      idempotencyKey,
      rideId: payment.ride_id,
      ridePaymentId: payment.id,
      reverseRouting: reversalPlan.reverseRouting,
      routingReversals:
        routed && !reversalPlan.reverseRouting && routingReversalCents > 0
          ? [{
            organizationId: route.organization_id,
            amountCents: routingReversalCents,
          }]
          : undefined,
    });
    await admin.from("ride_payment_refunds").update({
      provider_refund_id: providerRefund.id,
      state: ["queued", "pending", "processing", "refunded"].includes(
          providerRefund.status,
        )
        ? providerRefund.status
        : "pending",
      provider_snapshot: providerRefund,
      updated_at: new Date().toISOString(),
    }).eq("id", candidateId);
    await admin.from("ride_payment_events").insert({
      ride_payment_id: payment.id,
      ride_id: payment.ride_id,
      event_type: "refund_requested",
      provider_event_key: `refund:${providerRefund.id}`,
      from_state: payment.state,
      to_state: payment.state,
      actor_type: actor.type,
      actor_id: actor.id,
      source: actor.source,
      correlation_id: payment.correlation_id,
      payload: {
        command,
        amount_cents: amounts.refundableCents,
        retained_fee_cents: amounts.retainedFeeCents,
        routing_reversal_cents: routingReversalCents,
      },
    });
    await audit(admin, payment, actor, "payment.refund_requested", {
      command,
      amount_cents: amounts.refundableCents,
      retained_fee_cents: amounts.retainedFeeCents,
    });
    return {
      ok: true,
      refund: {
        id: candidateId,
        state: providerRefund.status,
        amount_cents: amounts.refundableCents,
      },
      pending_webhook_confirmation: true,
    };
  } catch (error) {
    await admin.from("ride_payment_refunds").update({
      state: "failed",
      provider_failure_code: "refund_create_failed",
      updated_at: new Date().toISOString(),
    }).eq("id", candidateId);
    throw error;
  }
}

async function voidUnrouted(
  admin: SupabaseClient,
  ride: RideRow,
  payment: PaymentRow,
  actor: CommandActor,
) {
  if (payment.state === "canceled" || payment.state === "expired") {
    return { ok: true, voided: true, idempotent_replay: true };
  }
  if (
    [
      "paid",
      "routing_pending",
      "routing_failed",
      "routed",
      "partially_refunded",
    ].includes(payment.state)
  ) {
    return await refundRidePayment(admin, ride, payment, "refund_full", actor);
  }
  if (
    !["creating", "open", "pending", "authorized"].includes(payment.state) ||
    !payment.provider_payment_id
  ) {
    return { ok: false, error: "payment_not_voidable", status: 409 };
  }
  await cancelMolliePayment(payment.provider_payment_id);
  await audit(admin, payment, actor, "payment.void_requested", {});
  return { ok: true, voided: true, pending_webhook_confirmation: true };
}

export async function runRidePaymentCommand(input: {
  admin: SupabaseClient;
  rideId: string;
  command: RidePaymentCommand;
  actor: CommandActor;
}) {
  const ride = await rideForId(input.admin, input.rideId);
  if (!ride) return { ok: false, error: "ride_not_found", status: 404 };
  if (input.command === "route_completed" && ride.status !== "completed") {
    return { ok: false, error: "ride_not_completed", status: 409 };
  }
  if (
    input.command === "capture_cancellation_fee" &&
    (ride.status !== "cancelled" || ride.cancelled_by !== "rider")
  ) {
    return {
      ok: false,
      error: "rider_cancellation_not_confirmed",
      status: 409,
    };
  }
  if (
    input.command === "capture_no_show_fee" &&
    (ride.status !== "cancelled" || ride.cancellation_reason !== "no_show")
  ) {
    return { ok: false, error: "rider_no_show_not_confirmed", status: 409 };
  }
  const payment = await paymentForRide(input.admin, input.rideId);
  if (!payment) {
    return input.command === "route_completed"
      ? { ok: true, skipped: "not_prepaid" }
      : { ok: false, error: "payment_not_found", status: 404 };
  }
  if (input.command === "route_completed") {
    return await routeCompletedRide(input.admin, payment, input.actor);
  }
  if (input.command === "void_unrouted") {
    return await voidUnrouted(input.admin, ride, payment, input.actor);
  }
  return await refundRidePayment(
    input.admin,
    ride,
    payment,
    input.command,
    input.actor,
  );
}

export async function reverseDriverRouting(input: {
  admin: SupabaseClient;
  rideId: string;
  actor: CommandActor;
}) {
  return await runRidePaymentCommand({
    ...input,
    command: "reverse_driver_routing",
  });
}
