import {
  authDriverId,
  corsOptions,
  json,
  serviceClient,
} from "../_shared/driver_billing_shared.ts";

const APPLE_VERIFY_PRODUCTION =
  "https://buy.itunes.apple.com/verifyReceipt";
const APPLE_VERIFY_SANDBOX =
  "https://sandbox.itunes.apple.com/verifyReceipt";

const PRODUCT_IDS = new Set([
  "nl.heycaby.driver.access.daily",
  "nl.heycaby.driver.access.weekly",
  "nl.heycaby.driver.access.monthly",
]);

const PLAN_PRODUCT: Record<string, string> = {
  daily: "nl.heycaby.driver.access.daily",
  weekly: "nl.heycaby.driver.access.weekly",
  monthly: "nl.heycaby.driver.access.monthly",
};

type AppleInApp = {
  product_id?: string;
  expires_date_ms?: string;
  transaction_id?: string;
  original_transaction_id?: string;
  cancellation_date_ms?: string;
};

type AppleVerifyResponse = {
  status: number;
  latest_receipt_info?: AppleInApp[];
  receipt?: { in_app?: AppleInApp[] };
};

async function verifyWithApple(
  url: string,
  receiptData: string,
  password: string,
): Promise<AppleVerifyResponse> {
  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      "receipt-data": receiptData,
      password,
      "exclude-old-transactions": false,
    }),
  });
  if (!res.ok) {
    throw new Error(`apple_http_${res.status}`);
  }
  return await res.json() as AppleVerifyResponse;
}

function collectRows(resp: AppleVerifyResponse): AppleInApp[] {
  const seen = new Set<string>();
  const out: AppleInApp[] = [];
  const add = (e: AppleInApp) => {
    const key = `${e.transaction_id}|${e.product_id}|${e.expires_date_ms}`;
    if (seen.has(key)) return;
    seen.add(key);
    out.push(e);
  };
  for (const e of resp.latest_receipt_info ?? []) {
    if (e.product_id && PRODUCT_IDS.has(e.product_id) && e.expires_date_ms) {
      add(e);
    }
  }
  for (const e of resp.receipt?.in_app ?? []) {
    if (e.product_id && PRODUCT_IDS.has(e.product_id) && e.expires_date_ms) {
      add(e);
    }
  }
  return out;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return corsOptions();
  if (req.method !== "POST") {
    return json({ ok: false, error: "method_not_allowed" }, 405);
  }

  try {
    const auth = await authDriverId(req);
    if (auth instanceof Response) return auth;

    const secret = (Deno.env.get("APPLE_APPSTORE_SHARED_SECRET") ?? "").trim();
    if (!secret) {
      return json({ ok: false, error: "apple_not_configured" }, 503);
    }

    const body = await req.json().catch(() => ({})) as Record<string, unknown>;
    const receiptData = String(body.receipt_data ?? "").trim();
    const planCode = String(body.plan_code ?? "").trim().toLowerCase();
    if (!receiptData) {
      return json({ ok: false, error: "receipt_required" }, 400);
    }

    let resp = await verifyWithApple(
      APPLE_VERIFY_PRODUCTION,
      receiptData,
      secret,
    );
    if (resp.status === 21007) {
      resp = await verifyWithApple(APPLE_VERIFY_SANDBOX, receiptData, secret);
    }
    if (resp.status !== 0) {
      return json({ ok: false, error: "apple_verify_failed", status: resp.status }, 400);
    }

    const rows = collectRows(resp);
    if (rows.length === 0) {
      return json({ ok: false, error: "no_subscription_entries" }, 400);
    }

    const expectedPid = planCode ? PLAN_PRODUCT[planCode] : null;
    const now = Date.now();
    let best: AppleInApp | null = null;
    let bestExpiry = 0;

    for (const row of rows) {
      if (expectedPid && row.product_id !== expectedPid) continue;
      if (row.cancellation_date_ms?.trim()) continue;
      const exp = Number(row.expires_date_ms ?? 0);
      if (!exp || exp <= now) continue;
      if (exp > bestExpiry) {
        bestExpiry = exp;
        best = row;
      }
    }
    if (!best?.transaction_id) {
      return json({ ok: false, error: "no_active_subscription" }, 400);
    }

    const expiresAt = new Date(bestExpiry).toISOString();
    const admin = serviceClient();
    const { error: updateErr } = await admin
      .from("drivers")
      .update({ subscription_expires_at: expiresAt })
      .eq("id", auth.driverId);
    if (updateErr) {
      return json({ ok: false, error: updateErr.message }, 500);
    }

    await admin.from("driver_payment_events").insert({
      driver_id: auth.driverId,
      amount_cents: 0,
      currency: "EUR",
      status: "paid",
      provider: "apple",
      mollie_payment_id: best.transaction_id,
      metadata: {
        product_id: best.product_id,
        transaction_id: best.transaction_id,
        original_transaction_id: best.original_transaction_id,
        plan_code: planCode,
        expires_at: expiresAt,
      },
    });

    return json({
      ok: true,
      subscription_expires_at: expiresAt,
      product_id: best.product_id,
    });
  } catch (e) {
    console.error("driver-billing-apple-verify:", e);
    return json({ ok: false, error: "internal_error" }, 500);
  }
});
