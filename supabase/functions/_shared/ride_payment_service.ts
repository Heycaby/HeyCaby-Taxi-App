import { createClient, SupabaseClient } from "jsr:@supabase/supabase-js@2";

export type MolliePayment = {
  id: string;
  status: string;
  amount: { currency: string; value: string };
  metadata?: Record<string, unknown>;
  paidAt?: string;
  canceledAt?: string;
  expiresAt?: string;
  _links?: { checkout?: { href?: string } };
  _embedded?: {
    refunds?: Array<MollieRefund>;
    chargebacks?: Array<MollieChargeback>;
  };
};

export type MollieRefund = {
  id: string;
  status: string;
  amount: { currency: string; value: string };
  metadata?: Record<string, unknown>;
  createdAt?: string;
};

export type MollieChargeback = {
  id: string;
  status?: string;
  amount: { currency: string; value: string };
  createdAt?: string;
};

export type MolliePaymentRoute = {
  id: string;
  amount: { currency: string; value: string };
  destination: { type: string; organizationId: string };
  releaseDate?: string;
};

export function json(body: object, status = 200): Response {
  return Response.json(body, {
    status,
    headers: { "Access-Control-Allow-Origin": "*" },
  });
}

export function corsOptions(): Response {
  return new Response(null, {
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
      "Access-Control-Allow-Headers":
        "Content-Type, Authorization, apikey, x-client-info",
    },
  });
}

export function serviceClient(): SupabaseClient {
  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!url || !key) throw new Error("missing_supabase_service_config");
  return createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

export async function authenticatedUserId(
  req: Request,
): Promise<string | Response> {
  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader.startsWith("Bearer ")) {
    return json({ ok: false, error: "unauthorized" }, 401);
  }
  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  if (!url || !anonKey) {
    return json({ ok: false, error: "server_misconfigured" }, 500);
  }
  const client = createClient(url, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data, error } = await client.auth.getUser();
  if (error || !data.user?.id) {
    return json({ ok: false, error: "unauthorized" }, 401);
  }
  return data.user.id;
}

export function parseJsonConfig(raw: unknown): Record<string, unknown> {
  if (typeof raw !== "string" || !raw.trim()) return {};
  try {
    const decoded = JSON.parse(raw);
    return decoded && typeof decoded === "object"
      ? decoded as Record<string, unknown>
      : {};
  } catch {
    return {};
  }
}

export function euroToCents(value: unknown): number | null {
  if (value === null || value === undefined || value === "") return null;
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed <= 0) return null;
  const cents = Math.round(parsed * 100);
  return cents > 0 ? cents : null;
}

export function selectBackendFareCents(
  ride: Record<string, unknown>,
): { amountCents: number; source: string } | null {
  const candidates: Array<[string, unknown, boolean]> = [
    ["final_fare", ride.final_fare, false],
    ["manual_fare_cents", ride.manual_fare_cents, true],
    ["offered_fare", ride.offered_fare, false],
    ["marketplace_offered_fare", ride.marketplace_offered_fare, false],
    ["quoted_fare", ride.quoted_fare, false],
    ["estimated_fare", ride.estimated_fare, false],
    ["estimated_price", ride.estimated_price, false],
  ];
  for (const [source, raw, alreadyCents] of candidates) {
    const amountCents = alreadyCents
      ? (Number.isInteger(Number(raw)) && Number(raw) > 0 ? Number(raw) : null)
      : euroToCents(raw);
    if (amountCents !== null) return { amountCents, source };
  }
  return null;
}

function mollieAccessToken(): string {
  const token = (Deno.env.get("MOLLIE_API_KEY") ?? "").trim();
  if (!token) throw new Error("mollie_not_configured");
  return token;
}

export function mollieEnvironment(): "test" | "live" {
  const token = mollieAccessToken();
  if (token.startsWith("test_")) return "test";
  if (token.startsWith("live_")) return "live";
  throw new Error("invalid_mollie_api_key");
}

async function mollieRequest<T>(
  path: string,
  init: RequestInit = {},
  accessToken = mollieAccessToken(),
): Promise<T> {
  const response = await fetch(`https://api.mollie.com/v2${path}`, {
    ...init,
    headers: {
      Authorization: `Bearer ${accessToken}`,
      Accept: "application/json",
      ...(init.body ? { "Content-Type": "application/json" } : {}),
      ...(init.headers ?? {}),
    },
  });
  const raw = await response.text();
  if (!response.ok) {
    console.error("mollie_request_failed", {
      path,
      status: response.status,
      requestId: response.headers.get("x-request-id"),
    });
    throw new Error(`mollie_request_failed:${response.status}`);
  }
  return (raw ? JSON.parse(raw) : undefined) as T;
}

export async function createMollieRidePayment(input: {
  amountCents: number;
  rideId: string;
  ridePaymentId: string;
  correlationId: string;
  redirectUrl: string;
  webhookUrl: string;
  idempotencyKey: string;
}): Promise<MolliePayment> {
  return await mollieRequest<MolliePayment>("/payments", {
    method: "POST",
    headers: { "Idempotency-Key": input.idempotencyKey },
    body: JSON.stringify({
      amount: {
        currency: "EUR",
        value: (input.amountCents / 100).toFixed(2),
      },
      description: `HeyCaby ride ${input.rideId.slice(0, 8)}`,
      redirectUrl: input.redirectUrl,
      webhookUrl: input.webhookUrl,
      metadata: {
        domain: "ride_prepayment",
        ride_id: input.rideId,
        ride_payment_id: input.ridePaymentId,
        correlation_id: input.correlationId,
      },
    }),
  });
}

export async function createMolliePaymentRoute(input: {
  paymentId: string;
  organizationId: string;
  amountCents: number;
  currency: string;
  idempotencyKey: string;
  description: string;
}): Promise<MolliePaymentRoute> {
  return await mollieRequest<MolliePaymentRoute>(
    `/payments/${encodeURIComponent(input.paymentId)}/routes`,
    {
      method: "POST",
      headers: { "Idempotency-Key": input.idempotencyKey },
      body: JSON.stringify({
        amount: {
          currency: input.currency,
          value: (input.amountCents / 100).toFixed(2),
        },
        destination: {
          type: "organization",
          organizationId: input.organizationId,
        },
        description: input.description.slice(0, 255),
      }),
    },
  );
}

export async function createMollieRefund(input: {
  paymentId: string;
  amountCents: number;
  currency: string;
  description: string;
  idempotencyKey: string;
  rideId: string;
  ridePaymentId: string;
  reverseRouting?: boolean;
  routingReversals?: Array<{
    organizationId: string;
    amountCents: number;
  }>;
}): Promise<MollieRefund> {
  return await mollieRequest<MollieRefund>(
    `/payments/${encodeURIComponent(input.paymentId)}/refunds`,
    {
      method: "POST",
      headers: { "Idempotency-Key": input.idempotencyKey },
      body: JSON.stringify({
        amount: {
          currency: input.currency,
          value: (input.amountCents / 100).toFixed(2),
        },
        description: input.description.slice(0, 255),
        metadata: {
          domain: "ride_prepayment_refund",
          ride_id: input.rideId,
          ride_payment_id: input.ridePaymentId,
        },
        ...(input.reverseRouting ? { reverseRouting: true } : {}),
        ...(input.routingReversals?.length
          ? {
            routingReversals: input.routingReversals.map((reversal) => ({
              amount: {
                currency: input.currency,
                value: (reversal.amountCents / 100).toFixed(2),
              },
              destination: {
                type: "organization",
                organizationId: reversal.organizationId,
              },
            })),
          }
          : {}),
      }),
    },
  );
}

export async function cancelMolliePayment(paymentId: string): Promise<void> {
  await mollieRequest<void>(
    `/payments/${encodeURIComponent(paymentId)}`,
    { method: "DELETE" },
  );
}

export async function fetchMolliePayment(
  paymentId: string,
): Promise<MolliePayment> {
  return await mollieRequest<MolliePayment>(
    `/payments/${encodeURIComponent(paymentId)}?include=refunds,chargebacks`,
  );
}

export async function exchangeMollieOAuthCode(input: {
  code: string;
  redirectUri: string;
}): Promise<{
  access_token: string;
  refresh_token: string;
  expires_in: number;
  scope?: string;
}> {
  const clientId = (Deno.env.get("MOLLIE_CONNECT_CLIENT_ID") ?? "").trim();
  const clientSecret = (Deno.env.get("MOLLIE_CONNECT_CLIENT_SECRET") ?? "")
    .trim();
  if (!clientId || !clientSecret) {
    throw new Error("mollie_connect_not_configured");
  }
  const response = await fetch("https://api.mollie.com/oauth2/tokens", {
    method: "POST",
    headers: {
      Authorization: `Basic ${btoa(`${clientId}:${clientSecret}`)}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: new URLSearchParams({
      grant_type: "authorization_code",
      code: input.code,
      redirect_uri: input.redirectUri,
    }),
  });
  if (!response.ok) {
    console.error("mollie_oauth_exchange_failed", { status: response.status });
    throw new Error(`mollie_oauth_exchange_failed:${response.status}`);
  }
  return await response.json();
}

export async function fetchMollieOrganization(
  accessToken: string,
): Promise<{ id: string; name?: string }> {
  return await mollieRequest<{ id: string; name?: string }>(
    "/organizations/me",
    {},
    accessToken,
  );
}

function base64(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}

function fromBase64(value: string): Uint8Array {
  const binary = atob(value);
  return Uint8Array.from(binary, (char) => char.charCodeAt(0));
}

function encryptionKeyBytes(): Uint8Array {
  const encoded = (Deno.env.get("MOLLIE_TOKEN_ENCRYPTION_KEY") ?? "").trim();
  if (!encoded) throw new Error("mollie_token_encryption_not_configured");
  const binary = atob(encoded);
  const bytes = Uint8Array.from(binary, (char) => char.charCodeAt(0));
  if (bytes.length !== 32) {
    throw new Error("invalid_mollie_token_encryption_key");
  }
  return bytes;
}

function bufferSource(bytes: Uint8Array): ArrayBuffer {
  return bytes.buffer.slice(
    bytes.byteOffset,
    bytes.byteOffset + bytes.byteLength,
  ) as ArrayBuffer;
}

export async function encryptMollieToken(plaintext: string): Promise<string> {
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const key = await crypto.subtle.importKey(
    "raw",
    bufferSource(encryptionKeyBytes()),
    "AES-GCM",
    false,
    ["encrypt"],
  );
  const encrypted = new Uint8Array(
    await crypto.subtle.encrypt(
      { name: "AES-GCM", iv },
      key,
      new TextEncoder().encode(plaintext),
    ),
  );
  return `v1.${base64(iv)}.${base64(encrypted)}`;
}

export async function decryptMollieToken(ciphertext: string): Promise<string> {
  const [version, ivRaw, encryptedRaw] = ciphertext.split(".");
  if (version !== "v1" || !ivRaw || !encryptedRaw) {
    throw new Error("invalid_mollie_token_ciphertext");
  }
  const key = await crypto.subtle.importKey(
    "raw",
    bufferSource(encryptionKeyBytes()),
    "AES-GCM",
    false,
    ["decrypt"],
  );
  const plaintext = await crypto.subtle.decrypt(
    { name: "AES-GCM", iv: bufferSource(fromBase64(ivRaw)) },
    key,
    bufferSource(fromBase64(encryptedRaw)),
  );
  return new TextDecoder().decode(plaintext);
}

export async function refreshMollieOAuthToken(refreshToken: string): Promise<{
  access_token: string;
  refresh_token: string;
  expires_in: number;
  scope?: string;
}> {
  const clientId = (Deno.env.get("MOLLIE_CONNECT_CLIENT_ID") ?? "").trim();
  const clientSecret = (Deno.env.get("MOLLIE_CONNECT_CLIENT_SECRET") ?? "")
    .trim();
  if (!clientId || !clientSecret) {
    throw new Error("mollie_connect_not_configured");
  }
  const response = await fetch("https://api.mollie.com/oauth2/tokens", {
    method: "POST",
    headers: {
      Authorization: `Basic ${btoa(`${clientId}:${clientSecret}`)}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: new URLSearchParams({
      grant_type: "refresh_token",
      refresh_token: refreshToken,
    }),
  });
  if (!response.ok) {
    console.error("mollie_oauth_refresh_failed", { status: response.status });
    throw new Error(`mollie_oauth_refresh_failed:${response.status}`);
  }
  return await response.json();
}

export async function fetchMollieOnboarding(accessToken: string): Promise<{
  status?: string;
  canReceivePayments?: boolean;
  canReceiveSettlements?: boolean;
}> {
  return await mollieRequest("/onboarding/me", {}, accessToken);
}

export async function sha256Hex(value: string): Promise<string> {
  const digest = new Uint8Array(
    await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value)),
  );
  return [...digest].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

export function webhookEventKey(payment: MolliePayment): string {
  return [
    payment.id,
    payment.status,
    payment.paidAt ?? payment.canceledAt ?? payment.expiresAt ?? "none",
    payment.amount?.currency ?? "",
    payment.amount?.value ?? "",
  ].join(":");
}

export function paymentAmountCents(payment: MolliePayment): number {
  return Math.round(Number(payment.amount?.value ?? "0") * 100);
}
