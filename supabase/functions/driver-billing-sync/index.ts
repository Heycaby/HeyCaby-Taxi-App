import {
  authDriverId,
  corsOptions,
  json,
  settlePaidPayment,
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

    const body = await req.json().catch(() => ({})) as Record<string, unknown>;
    const paymentId = String(
      body.mollie_payment_id ?? body.payment_id ?? body.id ?? "",
    ).trim();
    if (!paymentId) {
      return json({ ok: false, error: "missing_payment_id" }, 400);
    }

    const admin = serviceClient();
    const intentRes = await admin.rpc(
      "fn_driver_billing_checkout_intent_by_payment",
      { p_external_payment_id: paymentId },
    );
    const intent = intentRes.data as Record<string, unknown>;
    if (intent?.ok !== true || intent.driver_id !== auth.driverId) {
      return json({ ok: false, error: "forbidden" }, 403);
    }

    return await settlePaidPayment(admin, paymentId);
  } catch (e) {
    console.error("driver-billing-sync:", e);
    return json({ ok: false, error: "internal_error" }, 500);
  }
});
