/**
 * Direct APNs push notification sender (bypasses Firebase).
 * Requires secrets: APNS_PRIVATE_KEY, APNS_KEY_ID, APNS_TEAM_ID
 */

const APNS_KEY_ID = Deno.env.get("APNS_KEY_ID") ?? "";
const APNS_TEAM_ID = Deno.env.get("APNS_TEAM_ID") ?? "";
const APNS_PRIVATE_KEY_RAW = Deno.env.get("APNS_PRIVATE_KEY") ?? "";

type CachedJwt = { jwt: string; expiresMs: number };
let cachedJwt: CachedJwt | null = null;

export function isApnsConfigured(): boolean {
  return !!(APNS_KEY_ID && APNS_TEAM_ID && APNS_PRIVATE_KEY_RAW);
}

function getPemKey(): string {
  let raw = APNS_PRIVATE_KEY_RAW;
  if (raw.startsWith('"')) raw = JSON.parse(raw) as string;
  return raw;
}

async function signJwt(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedJwt && cachedJwt.expiresMs > Date.now() + 60_000) {
    return cachedJwt.jwt;
  }

  const header = { alg: "ES256", kid: APNS_KEY_ID };
  const payload = { iss: APNS_TEAM_ID, iat: now };

  const encoder = new TextEncoder();
  const headerB64 = base64UrlEncode(encoder.encode(JSON.stringify(header)));
  const payloadB64 = base64UrlEncode(encoder.encode(JSON.stringify(payload)));
  const signingInput = `${headerB64}.${payloadB64}`;

  const pem = getPemKey();
  const keyData = pemToDer(pem);
  const key = await crypto.subtle.importKey(
    "pkcs8",
    keyData,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );

  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    encoder.encode(signingInput),
  );

  const sigB64 = base64UrlEncode(new Uint8Array(signature));
  const jwt = `${signingInput}.${sigB64}`;
  cachedJwt = { jwt, expiresMs: Date.now() + 30 * 60 * 1000 };
  return jwt;
}

function base64UrlEncode(bytes: Uint8Array): string {
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(
    /=+$/,
    "",
  );
}

function pemToDer(pem: string): ArrayBuffer {
  const lines = pem.trim().split("\n");
  const base64 = lines
    .filter((l) => !l.startsWith("-----"))
    .join("");
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes.buffer;
}

export type ApnsSendInput = {
  title: string;
  body: string | null;
  data?: Record<string, unknown>;
  priority?: string;
  bundleId: string;
  environment?: "sandbox" | "production" | string | null;
};

export type ApnsSendResult = {
  ok: boolean;
  permanentFailure: boolean;
  statusCode?: number;
  errorCode?: string;
  providerMessageId?: string;
};

export function apnsHostForEnvironment(
  environment: ApnsSendInput["environment"],
): string {
  return environment === "sandbox"
    ? "api.sandbox.push.apple.com"
    : "api.push.apple.com";
}

export async function sendApnsToToken(
  deviceToken: string,
  nudge: ApnsSendInput,
): Promise<ApnsSendResult> {
  if (!isApnsConfigured()) {
    return {
      ok: false,
      permanentFailure: false,
      errorCode: "apns_not_configured",
    };
  }

  const jwt = await signJwt();
  const high = nudge.priority === "critical" || nudge.priority === "high";
  const incoming = nudge.data?.category === "incoming_ride";
  const badgeWorthy = incoming ||
    nudge.data?.category === "taxi_terug_offer_increased";
  const inviteId = typeof nudge.data?.ride_invite_id === "string"
    ? nudge.data.ride_invite_id
    : typeof nudge.data?.invite_id === "string"
    ? nudge.data.invite_id
    : undefined;
  const rideRequestId = typeof nudge.data?.ride_request_id === "string"
    ? nudge.data.ride_request_id
    : undefined;
  const expiresAt = typeof nudge.data?.expires_at === "string"
    ? Date.parse(nudge.data.expires_at)
    : Number.NaN;

  if (incoming && Number.isFinite(expiresAt) && expiresAt <= Date.now()) {
    return {
      ok: false,
      permanentFailure: false,
      errorCode: "invite_expired",
    };
  }

  const aps: Record<string, unknown> = {
    alert: {
      title: nudge.title,
      body: nudge.body ?? "",
    },
    sound: incoming ? "heycaby_ride_request.wav" : "default",
    "interruption-level": high ? "time-sensitive" : "active",
  };
  if (badgeWorthy) aps.badge = 1;
  if (incoming) {
    aps.category = "HEYCABY_INCOMING_RIDE";
    if (rideRequestId) aps["thread-id"] = rideRequestId;
  }

  const payload: Record<string, unknown> = { aps };
  if (nudge.data) {
    for (const [k, v] of Object.entries(nudge.data)) {
      if (v !== null && v !== undefined) {
        payload[k] = typeof v === "string" ? v : JSON.stringify(v);
      }
    }
  }

  const res = await fetch(
    `https://${
      apnsHostForEnvironment(nudge.environment)
    }/3/device/${deviceToken}`,
    {
      method: "POST",
      headers: {
        "authorization": `bearer ${jwt}`,
        "apns-topic": nudge.bundleId,
        "apns-push-type": "alert",
        "apns-priority": high ? "10" : "5",
        ...(inviteId ? { "apns-collapse-id": inviteId } : {}),
        ...(Number.isFinite(expiresAt)
          ? { "apns-expiration": Math.floor(expiresAt / 1000).toString() }
          : {}),
        "content-type": "application/json",
      },
      body: JSON.stringify(payload),
    },
  );

  if (!res.ok) {
    const errText = await res.text();
    let errorCode = "apns_error";
    try {
      const parsed = JSON.parse(errText) as { reason?: string };
      errorCode = parsed.reason ?? errorCode;
    } catch {}
    const permanent = [
      "BadDeviceToken",
      "Unregistered",
      "DeviceTokenNotForTopic",
    ]
      .includes(errorCode);
    console.error("APNs send failed:", res.status, errorCode);
    return {
      ok: false,
      permanentFailure: permanent,
      statusCode: res.status,
      errorCode,
    };
  }

  return {
    ok: true,
    permanentFailure: false,
    statusCode: res.status,
    providerMessageId: res.headers.get("apns-id") ?? undefined,
  };
}
