import {
  authenticatedUserId,
  corsOptions,
  createMollieRidePayment,
  json,
  mollieEnvironment,
  parseJsonConfig,
  selectBackendFareCents,
  serviceClient,
} from "../_shared/ride_payment_service.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return corsOptions();
  if (req.method !== "POST") {
    return json({ ok: false, error: "method_not_allowed" }, 405);
  }

  const userId = await authenticatedUserId(req);
  if (userId instanceof Response) return userId;

  let createdPaymentId: string | null = null;
  try {
    const body = await req.json().catch(() => ({})) as Record<string, unknown>;
    const rideId = String(body.ride_id ?? "").trim();
    const riderToken = String(body.rider_token ?? "").trim();
    const instantOptIn = body.instant_prepay_opt_in === true;
    if (!rideId) return json({ ok: false, error: "ride_id_required" }, 400);

    const admin = serviceClient();
    const [{ data: configRow }, { data: rideRaw, error: rideError }] =
      await Promise.all([
        admin.from("app_config").select("value").eq(
          "key",
          "ride_prepaid_payment_config",
        ).maybeSingle(),
        admin.from("ride_requests").select(
          "id, rider_identity_id, rider_token, driver_id, status, booking_mode, " +
            "final_fare, manual_fare_cents, offered_fare, marketplace_offered_fare, " +
            "quoted_fare, estimated_fare, estimated_price, scheduled_pickup_at",
        ).eq("id", rideId).maybeSingle(),
      ]);
    if (rideError || !rideRaw) {
      return json({ ok: false, error: "ride_not_found" }, 404);
    }
    const ride = rideRaw as unknown as Record<string, unknown> & {
      rider_identity_id: string | null;
      rider_token: string | null;
      driver_id: string | null;
      status: string;
      booking_mode: string;
    };

    const { data: identity } = ride.rider_identity_id
      ? await admin.from("rider_identities").select("user_id")
        .eq("id", ride.rider_identity_id).maybeSingle()
      : { data: null };
    const ownsRide = identity?.user_id === userId ||
      (riderToken.length > 0 && riderToken === ride.rider_token);
    if (!ownsRide) return json({ ok: false, error: "forbidden" }, 403);
    if (
      !["accepted", "driver_en_route", "driver_arrived"].includes(
        ride.status,
      ) || !ride.driver_id
    ) {
      return json({ ok: false, error: "ride_not_accepted" }, 409);
    }

    const mode = String(ride.booking_mode ?? "");
    if (mode === "instant" && !instantOptIn) {
      return json({ ok: false, error: "instant_prepay_opt_in_required" }, 400);
    }

    const decision = await admin.rpc("fn_ride_prepayment_checkout_decision", {
      p_ride_id: rideId,
      p_driver_id: ride.driver_id,
    });
    if (decision.error) throw decision.error;
    if (decision.data?.enabled !== true) {
      return json({
        ok: false,
        error: decision.data?.reason ?? "prepaid_payments_disabled",
      }, 409);
    }

    const { data: existing } = await admin.from("ride_payments")
      .select(
        "id, state, checkout_url, provider_payment_id, amount_cents, currency",
      )
      .eq("ride_id", rideId)
      .not("state", "in", "(failed,canceled,expired,refunded)")
      .order("created_at", { ascending: false }).limit(1).maybeSingle();
    if (existing) {
      return json({ ok: true, existing: true, payment: existing });
    }

    const { data: connection } = await admin.from("driver_mollie_connections")
      .select("organization_id, status, can_receive_prepaid_rides")
      .eq("driver_id", ride.driver_id).maybeSingle();
    if (
      !connection?.organization_id ||
      connection.can_receive_prepaid_rides !== true ||
      connection.status !== "verified"
    ) {
      return json({ ok: false, error: "driver_not_prepay_ready" }, 409);
    }

    const fare = selectBackendFareCents(ride);
    if (!fare) {
      return json({ ok: false, error: "backend_fare_unavailable" }, 409);
    }
    const config = parseJsonConfig(configRow?.value);
    const configuredEnvironment = String(config.environment ?? "").trim();
    if (configuredEnvironment !== mollieEnvironment()) {
      return json({ ok: false, error: "payment_environment_mismatch" }, 503);
    }
    // The accepted ride's immutable Driver Service Fee snapshot is the only
    // payout split authority. The legacy percentage remains a dark-launch
    // fallback only while the new fee feature is disabled.
    const feeSnapshot = await admin.rpc(
      "fn_prepare_prepaid_driver_service_fee",
      { p_ride_id: rideId, p_driver_id: ride.driver_id },
    );
    if (feeSnapshot.error) throw feeSnapshot.error;
    const serviceFeeEnabled = feeSnapshot.data?.enabled !== false &&
      feeSnapshot.data?.service_fee_cents !== undefined;
    const feeBps = Number(config.platform_fee_bps ?? 0);
    if (!serviceFeeEnabled &&
      (!Number.isInteger(feeBps) || feeBps < 0 || feeBps > 10000)) {
      return json({ ok: false, error: "payment_config_invalid" }, 503);
    }
    const platformFeeCents = serviceFeeEnabled
      ? Number(feeSnapshot.data.service_fee_cents)
      : Math.round(fare.amountCents * feeBps / 10000);
    if (!Number.isInteger(platformFeeCents) || platformFeeCents < 0 ||
      platformFeeCents > fare.amountCents) {
      return json({ ok: false, error: "driver_service_fee_invalid" }, 503);
    }
    const paymentId = crypto.randomUUID();
    createdPaymentId = paymentId;
    const idempotencyKey = crypto.randomUUID();
    const correlationId = crypto.randomUUID();
    const now = new Date().toISOString();
    const { error: insertError } = await admin.from("ride_payments").insert({
      id: paymentId,
      ride_id: rideId,
      rider_identity_id: ride.rider_identity_id,
      driver_id: ride.driver_id,
      destination_organization_id: connection.organization_id,
      amount_cents: fare.amountCents,
      platform_fee_cents: platformFeeCents,
      driver_route_cents: fare.amountCents - platformFeeCents,
      currency: "EUR",
      idempotency_key: idempotencyKey,
      correlation_id: correlationId,
      fare_snapshot: {
        source: fare.source,
        amount_cents: fare.amountCents,
        booking_mode: mode,
        captured_at: now,
        driver_service_fee_snapshot_id:
          feeSnapshot.data?.snapshot_id ?? null,
        driver_service_fee_config_id:
          feeSnapshot.data?.fee_config_id ?? null,
      },
    });
    if (insertError) throw insertError;

    const supabaseUrl = (Deno.env.get("SUPABASE_URL") ?? "").replace(/\/$/, "");
    const redirectBase = (Deno.env.get("MOLLIE_RIDE_REDIRECT_URL") ??
      "https://heycaby.nl/payment/return").replace(/\/$/, "");
    const payment = await createMollieRidePayment({
      amountCents: fare.amountCents,
      rideId,
      ridePaymentId: paymentId,
      correlationId,
      redirectUrl: `${redirectBase}?ride_id=${encodeURIComponent(rideId)}`,
      webhookUrl: `${supabaseUrl}/functions/v1/ride-payment-mollie-webhook`,
      idempotencyKey,
    });
    const checkoutUrl = payment._links?.checkout?.href ?? "";
    if (!checkoutUrl) throw new Error("mollie_checkout_url_missing");

    const { error: updateError } = await admin.from("ride_payments").update({
      provider_payment_id: payment.id,
      state: payment.status === "open" ? "open" : "pending",
      checkout_url: checkoutUrl,
      provider_snapshot: payment,
      updated_at: now,
    }).eq("id", paymentId);
    if (updateError) throw updateError;
    await admin.from("ride_payment_events").insert({
      ride_payment_id: paymentId,
      ride_id: rideId,
      event_type: "payment_created",
      from_state: "creating",
      to_state: payment.status === "open" ? "open" : "pending",
      source: "ride-payment-create",
      correlation_id: correlationId,
      payload: { provider: "mollie", provider_payment_id: payment.id },
    });
    await admin.from("ride_audit_log").insert({
      ride_id: rideId,
      event: "payment.prepaid_created",
      actor_id: userId,
      actor_type: "rider",
      source: "ride-payment-create",
      correlation_id: correlationId,
      metadata: { ride_payment_id: paymentId, amount_cents: fare.amountCents },
    });

    return json({
      ok: true,
      payment: {
        id: paymentId,
        state: payment.status === "open" ? "open" : "pending",
        checkout_url: checkoutUrl,
        amount_cents: fare.amountCents,
        currency: "EUR",
      },
    }, 201);
  } catch (error) {
    console.error("ride-payment-create", error);
    if (createdPaymentId) {
      await serviceClient().from("ride_payments").update({
        state: "failed",
        failure_code: "payment_create_failed",
        updated_at: new Date().toISOString(),
      }).eq("id", createdPaymentId).eq("state", "creating");
    }
    const code =
      error instanceof Error && error.message === "mollie_not_configured"
        ? "payment_provider_not_configured"
        : "payment_create_failed";
    return json({ ok: false, error: code }, 500);
  }
});
