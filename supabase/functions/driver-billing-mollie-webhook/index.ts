import {
  corsOptions,
  json,
  settlePaidPayment,
  serviceClient,
} from "../_shared/driver_billing_shared.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return corsOptions();
  if (req.method !== "POST") {
    return json({ ok: true });
  }

  try {
    const body = await req.json().catch(() => ({})) as Record<string, unknown>;
    const paymentId = String(body.id ?? "").trim();
    if (!paymentId) {
      return json({ ok: false, error: "missing_payment_id" }, 400);
    }

    const admin = serviceClient();
    return await settlePaidPayment(admin, paymentId);
  } catch (e) {
    console.error("driver-billing-mollie-webhook:", e);
    return json({ ok: false, error: "internal_error" }, 500);
  }
});
