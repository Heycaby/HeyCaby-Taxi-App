import { createClient, SupabaseClient } from "jsr:@supabase/supabase-js@2";

export function json(obj: object, status = 200): Response {
  return new Response(JSON.stringify(obj), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
    },
  });
}

export function corsOptions(): Response {
  return new Response(null, {
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      "Access-Control-Allow-Headers":
        "Content-Type, Authorization, apikey, x-client-info",
    },
  });
}

export function serviceClient(): SupabaseClient {
  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!url || !key) {
    throw new Error("missing_supabase_service_config");
  }
  return createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

export async function authDriverId(
  req: Request,
): Promise<{ driverId: string } | Response> {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return json({ ok: false, error: "unauthorized" }, 401);
  }
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const url = Deno.env.get("SUPABASE_URL") ?? "";
  if (!anonKey || !url) {
    return json({ ok: false, error: "server_misconfigured" }, 500);
  }
  const userClient = createClient(url, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: userData, error: userErr } = await userClient.auth.getUser();
  if (userErr || !userData.user?.id) {
    return json({ ok: false, error: "unauthorized" }, 401);
  }
  const admin = serviceClient();
  const { data: driver, error: driverErr } = await admin
    .from("drivers")
    .select("id")
    .eq("user_id", userData.user.id)
    .maybeSingle();
  if (driverErr || !driver?.id) {
    return json({ ok: false, error: "not_a_driver" }, 403);
  }
  return { driverId: driver.id as string };
}

type MolliePayment = {
  id: string;
  status: string;
  amount?: { currency?: string; value?: string };
  metadata?: Record<string, unknown>;
  _links?: { checkout?: { href?: string } };
};

export function mollieApiKey(): string {
  const key = (Deno.env.get("MOLLIE_API_KEY") ?? "").trim();
  if (!key) throw new Error("mollie_not_configured");
  return key;
}

export function mollieRedirectUrl(): string {
  const configured = (Deno.env.get("MOLLIE_REDIRECT_URL") ?? "").trim();
  return configured || "https://api.heycaby.nl/driver/payment/return";
}

export async function mollieCreatePayment(input: {
  amountCents: number;
  description: string;
  metadata: Record<string, unknown>;
  webhookUrl?: string;
}): Promise<MolliePayment> {
  const key = mollieApiKey();
  const body = {
    amount: {
      currency: "EUR",
      value: (input.amountCents / 100).toFixed(2),
    },
    description: input.description,
    redirectUrl: mollieRedirectUrl(),
    webhookUrl: input.webhookUrl,
    metadata: input.metadata,
  };
  const res = await fetch("https://api.mollie.com/v2/payments", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${key}`,
      "Content-Type": "application/json",
      Accept: "application/json",
    },
    body: JSON.stringify(body),
  });
  const raw = await res.text();
  if (!res.ok) {
    throw new Error(`mollie_create_failed:${res.status}:${raw}`);
  }
  return JSON.parse(raw) as MolliePayment;
}

export async function mollieFetchPayment(paymentId: string): Promise<MolliePayment> {
  const key = mollieApiKey();
  const res = await fetch(
    `https://api.mollie.com/v2/payments/${encodeURIComponent(paymentId)}`,
    {
      headers: {
        Authorization: `Bearer ${key}`,
        Accept: "application/json",
      },
    },
  );
  const raw = await res.text();
  if (!res.ok) {
    throw new Error(`mollie_fetch_failed:${res.status}:${raw}`);
  }
  return JSON.parse(raw) as MolliePayment;
}

export async function billingSummary(
  admin: SupabaseClient,
  driverId: string,
): Promise<{ outstanding: number; currency: string; countryCode: string }> {
  const { data, error } = await admin.rpc("fn_driver_billing_summary", {
    p_driver_id: driverId,
  });
  if (error) throw error;
  const summary = data as Record<string, unknown>;
  return {
    outstanding: Number(summary.outstanding ?? 0),
    currency: String(summary.currency ?? "EUR"),
    countryCode: String(summary.country_code ?? "NL"),
  };
}

export async function settlePaidPayment(
  admin: SupabaseClient,
  paymentId: string,
): Promise<Response> {
  const intentRes = await admin.rpc(
    "fn_driver_billing_checkout_intent_by_payment",
    { p_external_payment_id: paymentId },
  );
  if (intentRes.error) {
    return json({ ok: false, error: intentRes.error.message }, 500);
  }
  const intent = intentRes.data as Record<string, unknown>;
  if (intent?.ok !== true) {
    return json({ ok: false, error: "intent_not_found" }, 404);
  }
  if (intent.settlement_ledger_id) {
    return json({ ok: true, already_settled: true });
  }

  const payment = await mollieFetchPayment(paymentId);
  const status = (payment.status ?? "").toLowerCase();
  if (status !== "paid") {
    await admin
      .from("billing_checkout_intents")
      .update({ status, updated_at: new Date().toISOString() })
      .eq("provider", "mollie")
      .eq("external_payment_id", paymentId);
    return json({ ok: false, error: "not_paid", status });
  }

  const amountCents = Math.round(
    parseFloat(payment.amount?.value ?? "0") * 100,
  );

  if (intent.checkout_kind === "subscription") {
    const planCode = String(intent.plan_code ?? "weekly");
    const plan = subscriptionPlan(planCode);
    const days = plan?.durationDays ?? 7;
    const { data: driverRow } = await admin
      .from("drivers")
      .select("subscription_expires_at")
      .eq("id", intent.driver_id)
      .maybeSingle();
    const baseMs = Math.max(
      Date.now(),
      driverRow?.subscription_expires_at
        ? new Date(String(driverRow.subscription_expires_at)).getTime()
        : 0,
    );
    const expiresAt = new Date(baseMs + days * 24 * 60 * 60 * 1000).toISOString();
    const { error: updateErr } = await admin
      .from("drivers")
      .update({ subscription_expires_at: expiresAt })
      .eq("id", intent.driver_id);
    if (updateErr) {
      return json({ ok: false, error: updateErr.message }, 500);
    }
    await admin.from("driver_payment_events").insert({
      driver_id: intent.driver_id,
      amount_cents: amountCents,
      currency: "EUR",
      status: "paid",
      provider: "mollie",
      mollie_payment_id: paymentId,
      metadata: {
        plan_code: planCode,
        duration_days: days,
        checkout_kind: "subscription",
      },
    });
    await admin
      .from("billing_checkout_intents")
      .update({ status: "paid", updated_at: new Date().toISOString() })
      .eq("provider", "mollie")
      .eq("external_payment_id", paymentId);
    return json({
      ok: true,
      subscription_expires_at: expiresAt,
      checkout_kind: "subscription",
    });
  }

  const settleRes = await admin.rpc("fn_driver_billing_apply_settlement", {
    p_driver_id: intent.driver_id,
    p_paid_cents: amountCents,
    p_provider: "mollie",
    p_external_id: paymentId,
    p_metadata: {
      mollie_status: status,
      checkout_kind: intent.checkout_kind,
    },
  });
  if (settleRes.error) {
    return json({ ok: false, error: settleRes.error.message }, 500);
  }
  return json(settleRes.data as object);
}

const SUBSCRIPTION_PLANS: Record<
  string,
  { amountCents: number; durationDays: number; title: string }
> = {
  daily: { amountCents: 1210, durationDays: 1, title: "daily" },
  weekly: { amountCents: 7260, durationDays: 7, title: "weekly" },
  monthly: { amountCents: 24200, durationDays: 30, title: "monthly" },
};

export function subscriptionPlan(code: string) {
  return SUBSCRIPTION_PLANS[code.trim().toLowerCase()] ?? null;
}
