import {
  corsOptions,
  json,
  serviceClient,
  settlePaidPayment,
} from "../_shared/driver_billing_shared.ts";

async function paymentIdFromRequest(req: Request): Promise<string> {
  const contentType = req.headers.get("content-type") ?? "";
  const raw = await req.text();
  if (!raw.trim()) return "";

  if (contentType.includes("application/json")) {
    try {
      const body = JSON.parse(raw) as Record<string, unknown>;
      return String(body.id ?? body.payment_id ?? "").trim();
    } catch {
      return "";
    }
  }

  const params = new URLSearchParams(raw);
  return String(params.get("id") ?? params.get("payment_id") ?? "").trim();
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return corsOptions();
  if (req.method !== "POST") {
    return json({ ok: true });
  }

  try {
    const paymentId = await paymentIdFromRequest(req);
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
