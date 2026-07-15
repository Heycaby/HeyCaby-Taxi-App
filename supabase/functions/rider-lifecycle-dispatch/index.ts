import { GoogleAuth } from "npm:google-auth-library@9.15.1";
import {
  createClient,
  type SupabaseClient,
} from "jsr:@supabase/supabase-js@2";

import { resolveLifecycleDispatchSecret } from "./auth.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-webhook-secret",
};

type LifecycleJob = {
  id: string;
  rider_identity_id: string;
  campaign_key: string;
  title: string;
  body: string;
  data: Record<string, unknown> | null;
  priority: string | null;
};

type CachedToken = { token: string; expiresMs: number };
let cachedAccess: CachedToken | null = null;
const firebaseScope = "https://www.googleapis.com/auth/firebase.messaging";

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...corsHeaders },
  });
}

function stringifyData(data: Record<string, unknown> | null | undefined): Record<string, string> | undefined {
  if (!data) return undefined;
  const out: Record<string, string> = {};
  for (const [k, v] of Object.entries(data)) {
    if (v === null || v === undefined) continue;
    out[k] = typeof v === "string" ? v : JSON.stringify(v);
  }
  return Object.keys(out).length > 0 ? out : undefined;
}

async function getFirebaseAccessToken(): Promise<string | null> {
  const raw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
  if (!raw) return null;
  const now = Date.now();
  if (cachedAccess && cachedAccess.expiresMs > now + 60_000) return cachedAccess.token;
  const credentials = JSON.parse(raw) as Record<string, unknown>;
  const auth = new GoogleAuth({ credentials, scopes: [firebaseScope] });
  const client = await auth.getClient();
  const token = (await client.getAccessToken()).token ?? null;
  if (!token) return null;
  cachedAccess = { token, expiresMs: now + 3_500_000 };
  return token;
}

function getFirebaseProjectId(): string | null {
  const raw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
  if (!raw) return null;
  return (JSON.parse(raw) as { project_id?: string }).project_id ?? null;
}

async function sendFcmToToken(
  token: string,
  notification: { title: string; body: string; data?: Record<string, unknown>; priority?: string | null },
): Promise<boolean> {
  const accessToken = await getFirebaseAccessToken();
  const projectId = getFirebaseProjectId();
  if (!accessToken || !projectId) return false;

  const high = notification.priority === "critical" || notification.priority === "high";
  const data = stringifyData(notification.data);
  const message: Record<string, unknown> = {
    token,
    notification: { title: notification.title, body: notification.body },
    android: { priority: high ? "HIGH" : "NORMAL" },
    apns: {
      headers: { "apns-priority": high ? "10" : "5" },
      payload: { aps: { sound: "default" } },
    },
  };
  if (data) message.data = data;

  const res = await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ message }),
  });
  return res.ok;
}

async function dispatchJob(supabase: SupabaseClient<any>, job: LifecycleJob) {
  const { data: profile } = await supabase
    .from("rider_notification_profiles")
    .select("notifications_enabled")
    .eq("rider_identity_id", job.rider_identity_id)
    .maybeSingle();

  if (profile?.notifications_enabled === false) {
    await supabase.from("notification_lifecycle_jobs").update({
      status: "cancelled",
      last_error: "notifications_disabled",
      updated_at: new Date().toISOString(),
    }).eq("id", job.id);
    return { status: "cancelled" as const };
  }

  const { data: tokens } = await supabase
    .from("push_devices")
    .select("fcm_token")
    .eq("app_role", "rider")
    .eq("rider_identity_id", job.rider_identity_id);

  if (!tokens || tokens.length === 0) {
    await supabase.from("notification_lifecycle_jobs").update({
      status: "failed",
      last_error: "no_push_device_tokens",
      updated_at: new Date().toISOString(),
    }).eq("id", job.id);
    return { status: "failed" as const };
  }

  let sentAny = false;
  for (const tokenRow of tokens) {
    const fcmToken = tokenRow.fcm_token as string | null;
    if (!fcmToken) continue;
    const sent = await sendFcmToToken(fcmToken, {
      title: job.title,
      body: job.body,
      data: {
        ...(job.data ?? {}),
        campaign_key: job.campaign_key,
        lifecycle_job_id: job.id,
      },
      priority: job.priority,
    });
    if (sent) sentAny = true;
  }

  if (sentAny) {
    await supabase.from("notifications").insert({
      user_type: "rider",
      user_id: job.rider_identity_id,
      agent: "rider_lifecycle_dispatch",
      category: `lifecycle_${job.campaign_key}`,
      title: job.title,
      body: job.body,
      data: {
        ...(job.data ?? {}),
        campaign_key: job.campaign_key,
        lifecycle_job_id: job.id,
      },
      priority: job.priority ?? "medium",
      channel: "both",
      push_sent_at: new Date().toISOString(),
    });

    const profileUpdate: Record<string, string> = { updated_at: new Date().toISOString() };
    if (job.campaign_key === "welcome_signup") profileUpdate.welcome_sent_at = new Date().toISOString();
    if (job.campaign_key === "first_ride_nudge") profileUpdate.first_ride_nudge_sent_at = new Date().toISOString();
    if (job.campaign_key === "share_early") profileUpdate.share_nudge_sent_at = new Date().toISOString();
    if (job.campaign_key === "inactive_3d") profileUpdate.inactive_3d_sent_at = new Date().toISOString();
    if (job.campaign_key === "inactive_7d") profileUpdate.inactive_7d_sent_at = new Date().toISOString();
    if (job.campaign_key === "inactive_14d") profileUpdate.inactive_14d_sent_at = new Date().toISOString();

    await supabase.from("rider_notification_profiles").update(profileUpdate).eq("rider_identity_id", job.rider_identity_id);
    await supabase.from("notification_lifecycle_jobs").update({
      status: "sent",
      sent_at: new Date().toISOString(),
      last_error: null,
      updated_at: new Date().toISOString(),
    }).eq("id", job.id);
    return { status: "sent" as const };
  }

  await supabase.from("notification_lifecycle_jobs").update({
    status: "failed",
    last_error: "fcm_delivery_failed",
    updated_at: new Date().toISOString(),
  }).eq("id", job.id);
  return { status: "failed" as const };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !serviceRoleKey) {
      return jsonResponse({ success: false, error: "missing_supabase_env" }, 500);
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: vaultSecret } = await supabase.rpc(
      "fn_rider_agent_webhook_secret",
    );
    const dispatchSecret = resolveLifecycleDispatchSecret(vaultSecret);
    const incomingSecret = req.headers.get("x-webhook-secret");
    if (!dispatchSecret || incomingSecret !== dispatchSecret) {
      return jsonResponse({ success: false, error: "unauthorized" }, 401);
    }

    const body = await req.json().catch(() => ({}));
    if (body?.dry_run === true) {
      return jsonResponse({ success: true, mode: "dry_run" });
    }

    const limit = Math.min(Math.max(Number(body?.limit ?? 50), 1), 200);

    const { data: jobs, error: claimError } = await supabase
      .rpc("fn_claim_due_rider_lifecycle_jobs", { p_limit: limit });

    if (claimError) return jsonResponse({ success: false, error: claimError.message }, 500);

    let sent = 0;
    let failed = 0;
    let cancelled = 0;

    for (const rawJob of (jobs ?? [])) {
      const job = rawJob as LifecycleJob;
      const { data: campaign } = await supabase
        .from("notification_campaigns")
        .select("enabled, priority")
        .eq("campaign_key", job.campaign_key)
        .maybeSingle();

      if (!campaign?.enabled) {
        await supabase.from("notification_lifecycle_jobs").update({
          status: "cancelled",
          last_error: "campaign_disabled",
          updated_at: new Date().toISOString(),
        }).eq("id", job.id);
        cancelled++;
        continue;
      }

      job.priority = (campaign.priority as string | null) ?? job.priority;
      const result = await dispatchJob(supabase, job);
      if (result.status === "sent") sent++;
      else if (result.status === "cancelled") cancelled++;
      else failed++;
    }

    return jsonResponse({
      success: true,
      claimed: (jobs ?? []).length,
      sent,
      failed,
      cancelled,
    });
  } catch (error) {
    return jsonResponse({ success: false, error: String(error) }, 500);
  }
});
