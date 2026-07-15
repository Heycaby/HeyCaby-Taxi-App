import type { SupabaseClient } from "jsr:@supabase/supabase-js";

import {
  anonKey,
  createClient,
  serviceRoleKey,
  supabaseUrl,
} from "./config.ts";
import { notificationDeliveryGate } from "./invite_gate.ts";
import type { AgentNotificationRow, WebhookPayload } from "./notify_types.ts";
import {
  getDriverIdForRideRequest,
  recentPrerideNotification,
  sendPushNotification,
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

  const initialInviteGate = await notificationDeliveryGate(supabase, n);
  if (!initialInviteGate.live) {
    console.info(JSON.stringify({
      level: "info",
      message: "notification_delivery_suppressed",
      reason: initialInviteGate.reason,
      rideRequestId: n.data?.ride_request_id ?? null,
      rideInviteId: n.data?.ride_invite_id ?? n.data?.invite_id ?? null,
      driverId: n.user_id,
    }));
    return deliveryJson(n, {
      ok: true,
      skipped: true,
      reason: initialInviteGate.reason,
    });
  }
  if (n.category === "incoming_ride" && initialInviteGate.expiresAt) {
    n = {
      ...n,
      data: { ...n.data, expires_at: initialInviteGate.expiresAt },
    };
  }
  if (n.category === "incoming_ride" && n.data?.ride_request_id) {
    const { data: ride } = await supabase.from("ride_requests")
      .select("pickup_address")
      .eq("id", n.data.ride_request_id as string)
      .maybeSingle();
    const pickup = typeof ride?.pickup_address === "string"
      ? ride.pickup_address.trim()
      : "";
    if (pickup) n = { ...n, body: `Pickup: ${pickup}` };
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
    if (insertError.code === "23505" && n.data?.source_event_id) {
      return deliveryJson(n, {
        ok: true,
        skipped: true,
        reason: "duplicate_source_event",
      });
    }
    console.error("Insert notification error:", insertError);
    return json({ error: insertError.message }, 500);
  }

  let pushAttempted = false;
  let pushDeviceCount = 0;
  let pushAcceptedCount = 0;
  let pushFailedCount = 0;
  let invalidTokenCount = 0;
  let apnsAcceptedCount = 0;
  let fcmAcceptedCount = 0;
  const providerMessageIds: string[] = [];
  const pushErrorCodes = new Set<string>();
  let deliveredAuditWritten = false;

  if (n.channel !== "in_app" && n.channel !== "silent") {
    pushAttempted = true;
    let devices = supabase.from("push_devices").select(
      "id, fcm_token, apns_token, apns_environment, platform, app_role",
    );
    devices = n.target === "driver"
      ? devices.eq("driver_id", n.user_id).eq("app_role", "driver")
      : devices.eq("rider_identity_id", n.user_id).eq("app_role", "rider");
    const { data: rows, error: devicesError } = await devices;
    if (devicesError) {
      console.error(
        "driver-agent: push device lookup failed",
        devicesError.code,
      );
      pushErrorCodes.add("device_lookup_failed");
    }

    for (const row of rows ?? []) {
      const sendGate = await notificationDeliveryGate(supabase, n);
      if (!sendGate.live) {
        pushErrorCodes.add(sendGate.reason);
        console.info(JSON.stringify({
          level: "info",
          message: "notification_push_suppressed",
          reason: sendGate.reason,
          rideRequestId: n.data?.ride_request_id ?? null,
          rideInviteId: n.data?.ride_invite_id ?? n.data?.invite_id ?? null,
          driverId: n.user_id,
        }));
        break;
      }
      const token = row?.fcm_token as string | null;
      const apnsToken = row?.apns_token as string | null;
      if (
        (!token || token.length < 10) &&
        (!apnsToken || apnsToken.length < 10)
      ) continue;
      pushDeviceCount += 1;
      const result = await sendPushNotification(
        {
          fcm_token: token,
          apns_token: apnsToken,
          apns_environment: row?.apns_environment as string | null,
          platform: row?.platform as string,
          app_role: row?.app_role as string,
        },
        {
          title: n.title,
          body: n.body,
          data: {
            ...n.data,
            ...(sendGate.expiresAt ? { expires_at: sendGate.expiresAt } : {}),
            notification_id: inserted?.id,
            category: n.category,
          },
          priority: n.priority,
        },
      );
      if (
        result.ok && result.provider === "apns" && result.apnsEnvironment &&
        result.apnsEnvironment !== row?.apns_environment && row?.id
      ) {
        await supabase.from("push_devices").update({
          apns_environment: result.apnsEnvironment,
          updated_at: new Date().toISOString(),
        }).eq("id", row.id);
      }
      if (result.invalidApnsToken && row?.id) {
        invalidTokenCount += 1;
        await supabase.from("push_devices").update({
          apns_token: null,
          apns_environment: null,
          updated_at: new Date().toISOString(),
        }).eq("id", row.id);
      }
      if (result.ok) {
        pushAcceptedCount += 1;
        if (result.provider === "apns") apnsAcceptedCount += 1;
        if (result.provider === "fcm") fcmAcceptedCount += 1;
        if (result.providerMessageId) {
          providerMessageIds.push(result.providerMessageId);
        }
        continue;
      }
      pushFailedCount += 1;
      if (result.errorCode) pushErrorCodes.add(result.errorCode);
      if (result.permanentFailure && !result.invalidApnsToken && row?.id) {
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
      category: n.category,
      notification_id: inserted?.id,
      push_attempted: pushAttempted,
      push_device_count: pushDeviceCount,
      push_accepted_count: pushAcceptedCount,
      push_failed_count: pushFailedCount,
      invalid_token_count: invalidTokenCount,
      apns_accepted_count: apnsAcceptedCount,
      fcm_accepted_count: fcmAcceptedCount,
      provider_message_ids: providerMessageIds,
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
    apns_accepted_count: apnsAcceptedCount,
    fcm_accepted_count: fcmAcceptedCount,
    provider_message_ids: providerMessageIds,
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
