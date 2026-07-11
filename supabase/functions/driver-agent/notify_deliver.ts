import type { SupabaseClient } from "jsr:@supabase/supabase-js";

import {
  anonKey,
  createClient,
  serviceRoleKey,
  supabaseUrl,
} from "./config.ts";
import type { AgentNotificationRow, WebhookPayload } from "./notify_types.ts";
import {
  getDriverIdForRideRequest,
  recentPrerideNotification,
  sendFcmNotification,
} from "./notify_push.ts";
import { appendPingAudit } from "./ping_helpers.ts";
import { json, safeCompare } from "./util.ts";

function deliveryJson(
  notification: AgentNotificationRow,
  result: Record<string, unknown>,
): Response {
  return json({
    category: notification.category,
    channel: notification.channel,
    target: notification.target,
    ...result,
  });
}

export async function deliverNotification(
  supabase: SupabaseClient,
  notification: AgentNotificationRow,
  payloadForLog: unknown,
): Promise<Response> {
  let n = notification;
  if (n.user_id === "" && n.data?.ride_request_id) {
    const rideRequestId = n.data.ride_request_id as string;
    if (n.target === "rider") {
      const { data: ride } = await supabase
        .from("ride_requests")
        .select("rider_identity_id, rider_id")
        .eq("id", rideRequestId)
        .maybeSingle();
      const riderId = (ride?.rider_identity_id as string) ||
        (ride?.rider_id as string) || null;
      if (!riderId) {
        console.warn(
          "deliverNotification: could not resolve rider for ride_request_id",
          rideRequestId,
        );
        return deliveryJson(n, {
          ok: false,
          skipped: true,
          reason: "missing_rider",
        });
      }
      n = { ...n, user_id: riderId };
    } else {
      const driverId = await getDriverIdForRideRequest(supabase, rideRequestId);
      if (!driverId) {
        console.warn(
          "deliverNotification: could not resolve driver for ride_request_id",
          rideRequestId,
        );
        return deliveryJson(n, {
          ok: false,
          skipped: true,
          reason: "missing_driver",
        });
      }
      n = { ...n, user_id: driverId };
    }
  }
  if (!n.user_id) {
    console.warn("deliverNotification: no user_id, skipping", n.category);
    return deliveryJson(n, {
      ok: false,
      skipped: true,
      reason: "missing_recipient",
    });
  }

  if (n.category === "preride_request" && n.data?.ride_request_id) {
    const dup = await recentPrerideNotification(
      supabase,
      n.data.ride_request_id as string,
    );
    if (dup) {
      console.log(
        "deliverNotification: skipping duplicate preride_request",
        n.data.ride_request_id,
      );
      return deliveryJson(n, {
        ok: true,
        skipped: true,
        reason: "duplicate_preride_request",
      });
    }
  }

  const { data: inserted, error: insertError } = await supabase
    .from("notifications")
    .insert({
      user_type: n.user_type,
      user_id: n.user_id,
      agent: n.agent,
      category: n.category,
      title: n.title,
      body: n.body,
      data: n.data,
      priority: n.priority,
      channel: n.channel,
    })
    .select("id")
    .single();

  if (insertError) {
    console.error("Insert notification error:", insertError);
    return json({ error: insertError.message }, 500);
  }

  let pushAttempted = false;
  let pushDeviceCount = 0;
  let pushAcceptedCount = 0;
  let pushFailedCount = 0;
  let invalidTokenCount = 0;
  const pushErrorCodes = new Set<string>();
  let deliveredAuditWritten = false;

  if (n.channel !== "in_app" && n.channel !== "silent") {
    pushAttempted = true;
    let devices = supabase.from("push_devices").select("id, fcm_token");
    devices = n.target === "driver"
      ? devices.eq("driver_id", n.user_id).eq("app_role", "driver")
      : devices.eq("rider_identity_id", n.user_id).eq("app_role", "rider");
    const { data: rows, error: devicesError } = await devices;
    if (devicesError) {
      console.error("driver-agent: push device lookup failed", devicesError.code);
      pushErrorCodes.add("device_lookup_failed");
    }

    for (const row of rows ?? []) {
      const token = row?.fcm_token as string | null;
      if (!token || token.length < 10) continue;
      pushDeviceCount += 1;
      const result = await sendFcmNotification(token, {
        title: n.title,
        body: n.body,
        data: {
          ...n.data,
          notification_id: inserted?.id,
          category: n.category,
        },
        priority: n.priority,
      });
      if (result.ok) {
        pushAcceptedCount += 1;
        continue;
      }
      pushFailedCount += 1;
      if (result.errorCode) pushErrorCodes.add(result.errorCode);
      if (result.permanentFailure && row?.id) {
        invalidTokenCount += 1;
        await supabase.from("push_devices").delete().eq("id", row.id);
      }
    }

    if (inserted?.id && pushAcceptedCount > 0) {
      await supabase.from("notifications").update({
        push_sent_at: new Date().toISOString(),
      }).eq("id", inserted.id);
      const category = n.category ?? "";
      if (
        category.startsWith("driver_ping_") && n.data?.ride_request_id &&
        n.data?.audit_event
      ) {
        await appendPingAudit(
          supabase,
          n.data.ride_request_id as string,
          `${n.data.audit_event as string}.delivered`,
          null,
          {
            notification_id: inserted.id,
            delivery_state: "delivered",
            ping_kind: n.data.ping_kind ?? null,
          },
        );
        deliveredAuditWritten = true;
      }
    }
  }

  await supabase.from("agent_logs").insert({
    agent: "driver_agent",
    event_type: typeof payloadForLog === "object" && payloadForLog !== null &&
        "table" in (payloadForLog as object)
      ? `${(payloadForLog as WebhookPayload).table}_${
        (payloadForLog as WebhookPayload).type
      }`
      : "manual_preride_request",
    input: payloadForLog,
    output: {
      notification_id: inserted?.id,
      push_attempted: pushAttempted,
      push_device_count: pushDeviceCount,
      push_accepted_count: pushAcceptedCount,
      push_failed_count: pushFailedCount,
      invalid_token_count: invalidTokenCount,
      push_error_codes: [...pushErrorCodes],
      delivered_audit_written: deliveredAuditWritten,
    },
    notification_id: inserted?.id ?? null,
  });

  return deliveryJson(n, {
    ok: true,
    notification_id: inserted?.id ?? null,
    push_attempted: pushAttempted,
    push_device_count: pushDeviceCount,
    push_accepted_count: pushAcceptedCount,
    push_failed_count: pushFailedCount,
    invalid_token_count: invalidTokenCount,
    push_error_codes: [...pushErrorCodes],
    delivered_audit_written: deliveredAuditWritten,
  });
}

export async function authorizeManualPreride(
  req: Request,
  rideRequestId: string,
  webhookSecret = "",
): Promise<boolean> {
  if (webhookSecret) {
    const incomingSecret = req.headers.get("x-webhook-secret") ?? "";
    if (await safeCompare(incomingSecret, webhookSecret)) return true;
  }
  if (!anonKey) return false;
  const auth = req.headers.get("Authorization") ?? "";
  const m = auth.match(/^Bearer\s+(.+)$/i);
  if (!m) return false;
  const anonClient = createClient(supabaseUrl, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: { user } } = await anonClient.auth.getUser(m[1]);
  if (!user) return false;
  const sr = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: ride } = await sr.from("ride_requests").select("driver_id").eq(
    "id",
    rideRequestId,
  ).maybeSingle();
  const driverFk = ride?.driver_id as string | undefined;
  if (!driverFk) return false;
  const { data: drv } = await sr.from("drivers").select("user_id").eq(
    "id",
    driverFk,
  ).maybeSingle();
  return drv?.user_id === user.id;
}
