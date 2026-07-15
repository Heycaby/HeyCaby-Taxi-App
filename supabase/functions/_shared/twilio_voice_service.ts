import { createClient, SupabaseClient } from "jsr:@supabase/supabase-js@2";

export function json(body: object, status = 200): Response {
  return Response.json(body, { status, headers: { "Access-Control-Allow-Origin": "*" } });
}

export function corsOptions(): Response {
  return new Response(null, { headers: {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, Authorization, apikey, x-client-info",
  } });
}

export function serviceClient(): SupabaseClient {
  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!url || !key) throw new Error("missing_supabase_service_config");
  return createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });
}

export function userClient(req: Request): SupabaseClient {
  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const anon = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const authorization = req.headers.get("Authorization") ?? "";
  if (!url || !anon || !authorization.startsWith("Bearer ")) throw new Error("unauthorized");
  return createClient(url, anon, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

function twilioAccountSid(): string {
  const value = (Deno.env.get("TWILIO_ACCOUNT_SID") ?? "").trim();
  if (!/^AC[0-9a-fA-F]{32}$/.test(value)) throw new Error("twilio_not_configured");
  return value;
}

function twilioAuthToken(): string {
  const value = Deno.env.get("TWILIO_AUTH_TOKEN") ?? "";
  if (!value) throw new Error("twilio_not_configured");
  return value;
}

export function publicVoiceBaseUrl(): string {
  const value = (Deno.env.get("TWILIO_VOICE_PUBLIC_BASE_URL") ?? "").replace(/\/$/, "");
  if (!value.startsWith("https://")) throw new Error("twilio_public_url_invalid");
  return value;
}

export async function createBridgeCall(input: {
  attemptId: string; from: string; initiator: string;
}): Promise<{ sid: string; status: string }> {
  const sid = twilioAccountSid();
  const body = new URLSearchParams({
    To: input.initiator,
    From: input.from,
    Url: `${publicVoiceBaseUrl()}/twilio-voice-twiml?attempt_id=${encodeURIComponent(input.attemptId)}`,
    Method: "POST",
    StatusCallback: `${publicVoiceBaseUrl()}/twilio-voice-status-webhook?attempt_id=${encodeURIComponent(input.attemptId)}`,
    StatusCallbackMethod: "POST",
  });
  for (const event of ["initiated", "ringing", "answered", "completed"]) {
    body.append("StatusCallbackEvent", event);
  }
  const response = await fetch(`https://api.twilio.com/2010-04-01/Accounts/${sid}/Calls.json`, {
    method: "POST",
    headers: {
      Authorization: `Basic ${btoa(`${sid}:${twilioAuthToken()}`)}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body,
  });
  const payload = await response.json().catch(() => ({})) as Record<string, unknown>;
  if (!response.ok || typeof payload.sid !== "string") {
    console.error("twilio_call_create_failed", { status: response.status, code: payload.code });
    throw new Error(`twilio_call_create_failed:${response.status}`);
  }
  return { sid: payload.sid, status: String(payload.status ?? "queued") };
}

function bytesToBase64(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}

function timingSafeEqual(left: string, right: string): boolean {
  if (left.length !== right.length) return false;
  let mismatch = 0;
  for (let i = 0; i < left.length; i++) mismatch |= left.charCodeAt(i) ^ right.charCodeAt(i);
  return mismatch === 0;
}

export async function validateTwilioSignature(
  exactUrl: string, params: URLSearchParams, supplied: string,
): Promise<boolean> {
  if (!supplied) return false;
  const sorted = [...params.entries()].sort(([ak, av], [bk, bv]) =>
    ak === bk ? av.localeCompare(bv) : ak.localeCompare(bk)
  );
  const message = exactUrl + sorted.map(([key, value]) => `${key}${value}`).join("");
  const key = await crypto.subtle.importKey(
    "raw", new TextEncoder().encode(twilioAuthToken()),
    { name: "HMAC", hash: "SHA-1" }, false, ["sign"],
  );
  const signature = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(message));
  return timingSafeEqual(bytesToBase64(new Uint8Array(signature)), supplied);
}

export function callbackUrl(req: Request): string {
  const incoming = new URL(req.url);
  return `${publicVoiceBaseUrl()}${incoming.pathname}${incoming.search}`;
}

export function xmlEscape(value: string): string {
  return value.replaceAll("&", "&amp;").replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;").replaceAll('"', "&quot;").replaceAll("'", "&apos;");
}

export function twiml(body: string): Response {
  return new Response(`<?xml version="1.0" encoding="UTF-8"?><Response>${body}</Response>`, {
    status: 200, headers: { "Content-Type": "text/xml; charset=utf-8", "Cache-Control": "no-store" },
  });
}

export function normalizeCallStatus(raw: string): string {
  const value = raw.toLowerCase().replaceAll("-", "_");
  if (value === "answered") return "in_progress";
  if (["queued", "initiated", "ringing", "in_progress", "completed", "busy", "no_answer", "failed", "canceled"].includes(value)) return value;
  return "failed";
}

