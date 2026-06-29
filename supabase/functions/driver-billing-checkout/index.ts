import {
  authDriverId,
  billingSummary,
  corsOptions,
  json,
  mollieCreatePayment,
  serviceClient,
} from "../_shared/driver_billing_shared.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return corsOptions();
  if (req.method !== "POST") {
    return json({ ok: false, error: "method_not_allowed" }, 405);
  }

  try {
    const auth = await authDriverId(req);
    if (auth instanceof Response) return auth;

    await req.json().catch(() => ({}));

    const admin = serviceClient();
    const summary = await billingSummary(admin, auth.driverId);

    if (summary.outstanding <= 0) {
      return json({ ok: false, error: "nothing_to_settle" }, 400);
    }
    const amountCents = summary.outstanding;
    const checkoutKind = "settlement";

    const supabaseUrl = (Deno.env.get("SUPABASE_URL") ?? "").replace(/\/$/, "");
    const webhookUrl =
      `${supabaseUrl}/functions/v1/driver-billing-mollie-webhook`;

    const payment = await mollieCreatePayment({
      amountCents,
      description: "HeyCaby platform balance settlement",
      metadata: {
        driver_id: auth.driverId,
        checkout_kind: checkoutKind,
      },
      webhookUrl,
    });

    const checkoutUrl = payment._links?.checkout?.href ?? "";
    if (!checkoutUrl) {
      return json({ ok: false, error: "missing_checkout_url" }, 502);
    }

    const record = await admin.rpc("fn_driver_billing_record_checkout_intent", {
      p_driver_id: auth.driverId,
      p_amount_cents: amountCents,
      p_external_payment_id: payment.id,
      p_checkout_kind: checkoutKind,
      p_plan_code: null,
      p_currency: summary.currency,
      p_country_code: summary.countryCode,
      p_metadata: {
        checkout_kind: checkoutKind,
      },
    });
    if (record.error) {
      return json({ ok: false, error: record.error.message }, 500);
    }

    return json({
      ok: true,
      checkoutUrl,
      mollie_payment_id: payment.id,
      intent_id: (record.data as Record<string, unknown>)?.intent_id,
      amount_cents: amountCents,
    });
  } catch (e) {
    console.error("driver-billing-checkout:", e);
    const msg = e instanceof Error ? e.message : "internal_error";
    if (msg === "mollie_not_configured") {
      return json({ ok: false, error: "billing_not_configured" }, 503);
    }
    return json({ ok: false, error: "internal_error" }, 500);
  }
});
