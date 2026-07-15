import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import {
  authenticatedAdmin,
  corsOptions,
  json,
  serviceClient,
} from "../_shared/auth.ts";

type PushTarget =
  | "all"
  | "riders"
  | "drivers"
  | "zone"
  | "session"
  | "driver_id";

type NotificationPayload = {
  title: string;
  body: string;
  icon?: string;
  badge?: string;
  url?: string;
  tag?: string;
};

type Subscription = {
  id: string;
  endpoint: string;
  p256dh: string;
  auth: string;
  send_count: number;
};

const encoder = new TextEncoder();

function env(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) throw new Error(`missing_${name.toLowerCase()}`);
  return value;
}

function base64UrlToBytes(value: string): Uint8Array {
  const base64 = value.replace(/-/g, "+").replace(/_/g, "/");
  const padded = base64.padEnd(
    base64.length + (4 - base64.length % 4) % 4,
    "=",
  );
  return Uint8Array.from(atob(padded), (character) => character.charCodeAt(0));
}

function bytesToBase64Url(value: Uint8Array): string {
  return btoa(String.fromCharCode(...value))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=/g, "");
}

function wrapEcKeyInPkcs8(rawKey: Uint8Array): ArrayBuffer {
  const header = new Uint8Array([
    0x30,
    0x41,
    0x02,
    0x01,
    0x00,
    0x30,
    0x13,
    0x06,
    0x07,
    0x2a,
    0x86,
    0x48,
    0xce,
    0x3d,
    0x02,
    0x01,
    0x06,
    0x08,
    0x2a,
    0x86,
    0x48,
    0xce,
    0x3d,
    0x03,
    0x01,
    0x07,
    0x04,
    0x27,
    0x30,
    0x25,
    0x02,
    0x01,
    0x01,
    0x04,
    0x20,
  ]);
  const result = new Uint8Array(header.length + rawKey.length);
  result.set(header);
  result.set(rawKey, header.length);
  return result.buffer;
}

async function vapidJwt(audience: string): Promise<string> {
  const privateKey = await crypto.subtle.importKey(
    "pkcs8",
    wrapEcKeyInPkcs8(base64UrlToBytes(env("VAPID_PRIVATE_KEY"))),
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
  const header = bytesToBase64Url(
    encoder.encode(JSON.stringify({ typ: "JWT", alg: "ES256" })),
  );
  const payload = bytesToBase64Url(encoder.encode(JSON.stringify({
    aud: audience,
    exp: Math.floor(Date.now() / 1000) + 12 * 60 * 60,
    sub: Deno.env.get("VAPID_SUBJECT") ?? "mailto:info@heycaby.nl",
  })));
  const input = `${header}.${payload}`;
  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    privateKey,
    encoder.encode(input),
  );
  return `${input}.${bytesToBase64Url(new Uint8Array(signature))}`;
}

function cleanNotification(value: unknown): NotificationPayload | null {
  if (!value || typeof value !== "object") return null;
  const input = value as Record<string, unknown>;
  if (typeof input.title !== "string" || typeof input.body !== "string") {
    return null;
  }
  const title = input.title.trim();
  const body = input.body.trim();
  if (!title || !body || title.length > 120 || body.length > 500) return null;
  const optional = (key: string, max: number): string | undefined => {
    const candidate = input[key];
    return typeof candidate === "string" && candidate.length <= max
      ? candidate
      : undefined;
  };
  return {
    title,
    body,
    icon: optional("icon", 500),
    badge: optional("badge", 500),
    url: optional("url", 500),
    tag: optional("tag", 100),
  };
}

async function deliver(
  subscription: Subscription,
  notification: NotificationPayload,
): Promise<boolean> {
  const admin = serviceClient();
  try {
    const endpoint = new URL(subscription.endpoint);
    if (endpoint.protocol !== "https:") return false;
    const jwt = await vapidJwt(`${endpoint.protocol}//${endpoint.host}`);
    const response = await fetch(endpoint, {
      method: "POST",
      headers: {
        Authorization: `vapid t=${jwt},k=${env("VAPID_PUBLIC_KEY")}`,
        "Content-Type": "application/json",
        "Content-Encoding": "aes128gcm",
        TTL: "86400",
      },
      body: JSON.stringify({
        title: notification.title,
        body: notification.body,
        icon: notification.icon ?? "/icon-192.png",
        badge: notification.badge ?? "/badge-72.png",
        data: { url: notification.url ?? "/" },
        tag: notification.tag,
        renotify: Boolean(notification.tag),
      }),
      signal: AbortSignal.timeout(10_000),
    });
    if (!response.ok) {
      if (response.status === 404 || response.status === 410) {
        await admin.from("push_subscriptions").update({ is_active: false }).eq(
          "id",
          subscription.id,
        );
      }
      return false;
    }
    await admin.from("push_subscriptions").update({
      last_sent_at: new Date().toISOString(),
      send_count: subscription.send_count + 1,
    }).eq("id", subscription.id);
    return true;
  } catch (error) {
    console.error(
      "[send-push] delivery failed",
      error instanceof Error ? error.name : "unknown",
    );
    return false;
  }
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return corsOptions();
  if (request.method !== "POST") {
    return json({ ok: false, error: "method_not_allowed" }, 405);
  }

  const actor = await authenticatedAdmin(request);
  if (actor instanceof Response) return actor;

  let body: Record<string, unknown>;
  try {
    body = await request.json();
  } catch {
    return json({ ok: false, error: "invalid_json" }, 400);
  }

  const allowedTargets: PushTarget[] = [
    "all",
    "riders",
    "drivers",
    "zone",
    "session",
    "driver_id",
  ];
  const target = body.target as PushTarget;
  const notification = cleanNotification(body.notification);
  if (!allowedTargets.includes(target) || !notification) {
    return json({ ok: false, error: "invalid_request" }, 400);
  }

  const admin = serviceClient();
  let query = admin.from("push_subscriptions")
    .select("id,endpoint,p256dh,auth,send_count")
    .eq("is_active", true);
  if (target === "riders") query = query.eq("role", "rider");
  if (target === "drivers") query = query.eq("role", "driver");
  if (target === "zone") {
    if (typeof body.zone !== "string" || !body.zone.trim()) {
      return json({ ok: false, error: "zone_required" }, 400);
    }
    query = query.eq("zone_name", body.zone.trim());
  }
  if (target === "session") {
    if (typeof body.session_token !== "string" || !body.session_token) {
      return json({ ok: false, error: "session_required" }, 400);
    }
    query = query.eq("session_token", body.session_token);
  }
  if (target === "driver_id") {
    if (typeof body.driver_user_id !== "string" || !body.driver_user_id) {
      return json({ ok: false, error: "driver_required" }, 400);
    }
    query = query.eq("driver_user_id", body.driver_user_id);
  }

  const { data, error } = await query.limit(10_000);
  if (error) {
    console.error("[send-push] subscription query failed", error);
    return json({ ok: false, error: "subscription_query_failed" }, 500);
  }

  const subscriptions = (data ?? []) as Subscription[];
  let sent = 0;
  for (let offset = 0; offset < subscriptions.length; offset += 100) {
    const results = await Promise.all(
      subscriptions.slice(offset, offset + 100).map((subscription) =>
        deliver(subscription, notification)
      ),
    );
    sent += results.filter(Boolean).length;
  }

  console.log(
    `[send-push] admin=${actor.id} target=${target} total=${subscriptions.length} sent=${sent}`,
  );
  return json({
    ok: true,
    sent,
    failed: subscriptions.length - sent,
    total: subscriptions.length,
  });
});
