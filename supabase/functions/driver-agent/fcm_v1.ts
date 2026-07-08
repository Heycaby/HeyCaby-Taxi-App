/**
 * Firebase Cloud Messaging HTTP v1 (single delivery path; no Expo).
 * Requires secret FIREBASE_SERVICE_ACCOUNT_JSON (full service account JSON object as string).
 */
import { GoogleAuth } from "npm:google-auth-library@9.15.1";

const scope = "https://www.googleapis.com/auth/firebase.messaging";

type CachedToken = { token: string; expiresMs: number };
let cachedAccess: CachedToken | null = null;

export function getFirebaseProjectId(): string | null {
  const raw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
  if (!raw) return null;
  try {
    return (JSON.parse(raw) as { project_id?: string }).project_id ?? null;
  } catch {
    return null;
  }
}

export async function getFirebaseAccessToken(): Promise<string | null> {
  const raw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
  if (!raw) {
    console.error("FIREBASE_SERVICE_ACCOUNT_JSON is not set — FCM disabled");
    return null;
  }
  const now = Date.now();
  if (cachedAccess && cachedAccess.expiresMs > now + 60_000) {
    return cachedAccess.token;
  }
  let credentials: Record<string, unknown>;
  try {
    credentials = JSON.parse(raw) as Record<string, unknown>;
  } catch (e) {
    console.error("FIREBASE_SERVICE_ACCOUNT_JSON parse error:", e);
    return null;
  }
  const auth = new GoogleAuth({
    credentials,
    scopes: [scope],
  });
  const client = await auth.getClient();
  const res = await client.getAccessToken();
  const token = res.token ?? null;
  if (!token) {
    console.error("FCM: empty access token from GoogleAuth");
    return null;
  }
  cachedAccess = { token, expiresMs: now + 3_500_000 };
  return token;
}

export type FcmSendInput = {
  title: string;
  body: string | null;
  data?: Record<string, unknown>;
  priority?: string;
  androidChannelId?: string;
};

function stringifyData(
  data: Record<string, unknown> | undefined,
): Record<string, string> | undefined {
  if (!data || Object.keys(data).length === 0) return undefined;
  const out: Record<string, string> = {};
  for (const [k, v] of Object.entries(data)) {
    if (v === null || v === undefined) continue;
    out[k] = typeof v === "string" ? v : JSON.stringify(v);
  }
  return Object.keys(out).length ? out : undefined;
}

export async function sendFcmV1ToToken(
  deviceToken: string,
  nudge: FcmSendInput,
): Promise<boolean> {
  const access = await getFirebaseAccessToken();
  const projectId = getFirebaseProjectId();
  if (!access || !projectId) return false;

  const high = nudge.priority === "critical" || nudge.priority === "high";
  const dataPayload = stringifyData(nudge.data);

  const androidBlock: Record<string, unknown> = {
    priority: high ? "HIGH" : "NORMAL",
  };
  if (nudge.androidChannelId) {
    androidBlock.notification = {
      channel_id: nudge.androidChannelId,
      sound: "default",
      default_vibrate_timings: false,
      vibrate_timings: high
        ? ["0s", "0.4s", "0.2s", "0.4s"]
        : ["0s", "0.25s", "0.15s", "0.25s"],
    };
  }

  const message: Record<string, unknown> = {
    token: deviceToken,
    notification: {
      title: nudge.title,
      body: nudge.body ?? "",
    },
    android: androidBlock,
    apns: {
      headers: {
        "apns-priority": high ? "10" : "5",
      },
      payload: {
        aps: {
          sound: "default",
        },
      },
    },
  };
  if (dataPayload) {
    message.data = dataPayload;
  }

  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${access}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ message }),
    },
  );

  if (!res.ok) {
    const errText = await res.text();
    console.error("FCM v1 send failed:", res.status, errText);
    return false;
  }
  return true;
}
