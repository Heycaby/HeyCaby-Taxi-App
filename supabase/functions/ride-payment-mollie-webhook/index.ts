import {
  corsOptions,
  fetchMolliePayment,
  json,
  paymentAmountCents,
  serviceClient,
  webhookEventKey,
} from "../_shared/ride_payment_service.ts";

async function paymentIdFromRequest(req: Request): Promise<string> {
  const raw = await req.text();
  if (!raw.trim()) return "";
  if ((req.headers.get("content-type") ?? "").includes("application/json")) {
    try {
      const body = JSON.parse(raw) as Record<string, unknown>;
      return String(body.id ?? "").trim();
    } catch {
      return "";
    }
  }
  return String(new URLSearchParams(raw).get("id") ?? "").trim();
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return corsOptions();
  if (req.method !== "POST") return json({ ok: true });
  let deliveryId: string | null = null;
  try {
    const paymentId = await paymentIdFromRequest(req);
    if (!paymentId) {
      return json({ ok: false, error: "payment_id_required" }, 400);
    }

    const admin = serviceClient();
    const { data: localPayment, error: lookupError } = await admin
      .from("ride_payments")
      .select("id, ride_id, correlation_id")
      .eq("provider", "mollie")
      .eq("provider_payment_id", paymentId)
      .maybeSingle();
    if (lookupError) throw lookupError;
    if (!localPayment) {
      // Reject unknown IDs before making a provider request. This prevents the
      // public webhook endpoint from becoming an unauthenticated Mollie API
      // proxy while preserving Mollie's ID-only webhook contract.
      return json({ ok: false, error: "payment_not_found" }, 404);
    }
    const { data: delivery, error: deliveryError } = await admin
      .from("ride_payment_webhook_deliveries").insert({
        provider_payment_id: paymentId,
        ride_payment_id: localPayment.id,
        ride_id: localPayment.ride_id,
        correlation_id: localPayment.correlation_id,
      }).select("id").single();
    if (deliveryError) throw deliveryError;
    deliveryId = delivery.id;

    // Mollie's classic webhook contains only an entity ID. Authenticity and
    // current state are established by fetching that entity with our API key.
    const payment = await fetchMolliePayment(paymentId);
    const metadata = payment.metadata ?? {};
    if (
      metadata.domain !== "ride_prepayment" ||
      metadata.ride_id !== localPayment.ride_id ||
      metadata.ride_payment_id !== localPayment.id
    ) {
      await admin.from("ride_payment_webhook_deliveries").update({
        outcome: "rejected",
        error_code: "wrong_payment_domain",
        completed_at: new Date().toISOString(),
      }).eq("id", deliveryId);
      return json({ ok: false, error: "wrong_payment_domain" }, 404);
    }
    const result = await admin.rpc(
      "fn_ride_payment_apply_provider_snapshot",
      {
        p_provider_payment_id: payment.id,
        p_provider_event_key: webhookEventKey(payment),
        p_provider_status: payment.status,
        p_amount_cents: paymentAmountCents(payment),
        p_currency: payment.amount.currency,
        p_provider_snapshot: payment,
      },
    );
    if (result.error) throw result.error;
    if (result.data?.ok !== true) {
      console.error("ride_payment_webhook_rejected", {
        paymentId,
        error: result.data?.error,
      });
      await admin.from("ride_payment_webhook_deliveries").update({
        outcome: "rejected",
        error_code: result.data?.error ?? "rejected",
        completed_at: new Date().toISOString(),
      }).eq("id", deliveryId);
      return json({ ok: false, error: result.data?.error ?? "rejected" }, 409);
    }

    for (const providerRefund of payment._embedded?.refunds ?? []) {
      const state =
        ["queued", "pending", "processing", "refunded", "failed", "canceled"]
            .includes(providerRefund.status)
          ? providerRefund.status
          : "pending";
      await admin.from("ride_payment_refunds").update({
        state,
        provider_snapshot: providerRefund,
        completed_at: ["refunded", "failed", "canceled"].includes(state)
          ? new Date().toISOString()
          : null,
        updated_at: new Date().toISOString(),
      }).eq("ride_payment_id", localPayment.id)
        .eq("provider_refund_id", providerRefund.id);
    }
    const { data: confirmedRefunds } = await admin.from("ride_payment_refunds")
      .select("amount_cents, routing_reversal_cents")
      .eq("ride_payment_id", localPayment.id).eq("state", "refunded");
    const refundedCents = (confirmedRefunds ?? []).reduce(
      (sum, row) => sum + Number(row.amount_cents ?? 0),
      0,
    );
    const reversedCents = (confirmedRefunds ?? []).reduce(
      (sum, row) => sum + Number(row.routing_reversal_cents ?? 0),
      0,
    );
    if (refundedCents > 0) {
      const amountCents = paymentAmountCents(payment);
      await admin.from("ride_payments").update({
        refunded_cents: Math.min(refundedCents, amountCents),
        state: refundedCents >= amountCents ? "refunded" : "partially_refunded",
        updated_at: new Date().toISOString(),
      }).eq("id", localPayment.id);
      const { data: route } = await admin.from("ride_payment_routes")
        .select("id, amount_cents, state").eq(
          "ride_payment_id",
          localPayment.id,
        )
        .maybeSingle();
      if (
        route?.state === "routed" && reversedCents >= Number(route.amount_cents)
      ) {
        await admin.from("ride_payment_routes").update({
          state: "reversed",
          updated_at: new Date().toISOString(),
        }).eq("id", route.id);
      }
    }

    for (const chargeback of payment._embedded?.chargebacks ?? []) {
      await admin.from("ride_payment_chargebacks").upsert({
        ride_payment_id: localPayment.id,
        provider_chargeback_id: chargeback.id,
        amount_cents: Math.round(Number(chargeback.amount.value) * 100),
        state: chargeback.status ?? "observed",
        provider_snapshot: chargeback,
        updated_at: new Date().toISOString(),
      }, { onConflict: "provider_chargeback_id" });
    }
    await admin.from("ride_payment_webhook_deliveries").update({
      outcome: result.data?.idempotent_replay === true
        ? "duplicate"
        : "processed",
      completed_at: new Date().toISOString(),
    }).eq("id", deliveryId);
    return json({ ok: true });
  } catch (error) {
    console.error("ride-payment-mollie-webhook", error);
    if (deliveryId) {
      await serviceClient().from("ride_payment_webhook_deliveries").update({
        outcome: "failed",
        error_code: "webhook_processing_failed",
        completed_at: new Date().toISOString(),
      }).eq("id", deliveryId);
    }
    return json({ ok: false, error: "webhook_processing_failed" }, 500);
  }
});
