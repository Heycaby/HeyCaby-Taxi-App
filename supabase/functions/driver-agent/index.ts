// Driver Agent — transactional push via FCM HTTP v1 + rider pre-ride nudges.
// Triggered by DB webhooks (ride_requests, messages, ride_ratings) or
// POST { event: "preride_request", ride_request_id } with x-webhook-secret
// or Authorization: Bearer <driver JWT>.

import {
  createClient,
  serviceRoleKey,
  supabaseUrl,
  WEBHOOK_SECRET,
} from "./config.ts";
import { buildAgentNotification } from "./notify_rules.ts";
import type {
  AgentNotificationRow,
  FavoriteAddedPayload,
  ManualDriverPingPayload,
  ManualPreridePayload,
  WebhookPayload,
} from "./notify_types.ts";
import {
  authorizeManualPreride,
  deliverNotification,
} from "./notify_deliver.ts";
import { sendFcmNotification } from "./notify_push.ts";
import {
  appendPingAudit,
  buildPingCopy,
  hasAutomaticPing,
  normalizePingKind,
  pingAuditEvent,
  pingNotificationCategory,
  recentPingCooldown,
} from "./ping_helpers.ts";
import { json, ok, safeCompare } from "./util.ts";

async function enrichInviteNotification(
  supabase: { from: (table: string) => any },
  payload: WebhookPayload,
  notification: AgentNotificationRow,
): Promise<AgentNotificationRow> {
  if (
    payload.table !== "ride_request_invites" ||
    payload.type !== "INSERT" ||
    notification.category !== "incoming_ride"
  ) {
    return notification;
  }

  const rideRequestId = payload.record?.ride_request_id as string | undefined;
  if (!rideRequestId) return notification;

  const { data: ride, error } = await supabase
    .from("ride_requests")
    .select("booking_mode, return_mode_active")
    .eq("id", rideRequestId)
    .maybeSingle();
  const rideRow = ride as
    | { booking_mode?: string | null; return_mode_active?: boolean | null }
    | null;

  if (error) {
    console.warn(
      "driver-agent: could not enrich invite notification",
      rideRequestId,
      error.message,
    );
    return notification;
  }

  const bookingMode = rideRow?.booking_mode ?? undefined;
  const isTaxiTerug = bookingMode === "terug" ||
    rideRow?.return_mode_active === true;
  if (!isTaxiTerug) return notification;

  return {
    ...notification,
    title: "TAXI TERUG request",
    body: "This ride may fit your route back.",
    data: {
      ...(notification.data ?? {}),
      booking_mode: "terug",
      taxi_terug: true,
    },
  };
}

Deno.serve(async (req) => {
  try {
    if (req.method === "OPTIONS") return ok();

    const raw = await req.text();
    let body: unknown;
    try {
      body = JSON.parse(raw);
    } catch {
      return json({ error: "Invalid JSON" }, 400);
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const manual = body as
      | ManualPreridePayload
      | ManualDriverPingPayload
      | FavoriteAddedPayload;

    if (manual?.event === "driver_ping" && manual.ride_request_id) {
      const ping = manual as ManualDriverPingPayload;
      const kind = normalizePingKind(ping.kind);
      if (!kind) return json({ error: "invalid_ping_kind" }, 400);

      const authorized = await authorizeManualPreride(
        req,
        ping.ride_request_id,
      );
      if (!authorized) {
        console.warn(
          "driver-agent: rejected driver_ping (no secret / invalid JWT)",
        );
        return json({ error: "Unauthorized" }, 401);
      }

      const auditEvent = pingAuditEvent(kind);
      const isAutomatic = ping.automatic === true;

      if (isAutomatic) {
        if (
          await hasAutomaticPing(supabase, ping.ride_request_id, auditEvent)
        ) {
          return json({ ok: true, skipped: true, reason: "automatic_dedupe" });
        }
      } else if (
        await recentPingCooldown(supabase, ping.ride_request_id, auditEvent)
      ) {
        return json({ error: "ping_cooldown", retry_after_seconds: 30 }, 429);
      }

      const { data: ride } = await supabase
        .from("ride_requests")
        .select("id, rider_identity_id, driver_id, status")
        .eq("id", ping.ride_request_id)
        .maybeSingle();
      const rid = ride?.rider_identity_id as string | undefined;
      const driverFk = ride?.driver_id as string | undefined;
      const rideStatus = (ride?.status as string | undefined) ?? "";
      if (!rid) return json({ error: "ride_not_found" }, 400);
      if (
        !driverFk ||
        !["accepted", "driver_arrived", "arrived", "in_progress"].includes(
          rideStatus,
        )
      ) {
        return json(
          { error: "ride_not_active", status: rideStatus || null },
          409,
        );
      }

      let driverRow: Record<string, unknown> | null = null;
      const { data: drv } = await supabase
        .from("drivers")
        .select(
          "vehicle_plate, vehicle_make, vehicle_model, rdw_merk, rdw_handelsbenaming, user_id",
        )
        .eq("id", driverFk)
        .maybeSingle();
      driverRow = (drv as Record<string, unknown>) ?? null;

      const copy = buildPingCopy(kind, driverRow, ping.eta_minutes ?? null);
      const category = pingNotificationCategory(kind);
      const actorUserId = (driverRow?.user_id as string | undefined) ?? null;

      await appendPingAudit(
        supabase,
        ping.ride_request_id,
        auditEvent,
        actorUserId,
        {
          ping_kind: kind === "nearby" ? "on_my_way" : kind,
          vehicle_plate: driverRow?.vehicle_plate ?? null,
          eta_minutes: ping.eta_minutes ?? null,
          delivery_state: "sent",
          automatic: isAutomatic,
          source: isAutomatic ? "automatic" : "manual",
        },
      );

      const notification: AgentNotificationRow = {
        target: "rider",
        user_type: "rider",
        user_id: rid,
        agent: "driver_agent",
        category,
        title: copy.title,
        body: copy.body,
        data: {
          ride_request_id: ping.ride_request_id,
          screen: "active",
          ping_kind: kind === "nearby" ? "on_my_way" : kind,
          audit_event: auditEvent,
          vehicle_label: driverRow
            ? `${driverRow.rdw_merk ?? driverRow.vehicle_make ?? ""} ${
              driverRow.rdw_handelsbenaming ?? driverRow.vehicle_model ?? ""
            }`.trim()
            : "",
          vehicle_plate: driverRow?.vehicle_plate ?? "",
          android_channel_id: copy.channelId,
          notification_type: "driver_ping",
        },
        priority: copy.priority,
        channel: "both",
      };
      return await deliverNotification(supabase, notification, ping);
    }

    if (manual?.event === "preride_request" && manual.ride_request_id) {
      const authorized = await authorizeManualPreride(
        req,
        manual.ride_request_id,
      );
      if (!authorized) {
        console.warn(
          "driver-agent: rejected preride_request (no secret / invalid JWT)",
        );
        return json({ error: "Unauthorized" }, 401);
      }
      const { data: ride } = await supabase
        .from("ride_requests")
        .select("id, rider_identity_id, rider_preride_request_sent_at")
        .eq("id", manual.ride_request_id)
        .maybeSingle();
      const rid = ride?.rider_identity_id as string | undefined;
      const sent = ride?.rider_preride_request_sent_at;
      if (!rid || !sent) return json({ error: "ride_not_ready" }, 400);

      const notification: AgentNotificationRow = {
        target: "rider",
        user_type: "rider",
        user_id: rid,
        agent: "driver_agent",
        category: "preride_request",
        title: "Bevestig je rit",
        body: "Je chauffeur vraagt je rit te bevestigen vóór de rit.",
        data: { ride_request_id: manual.ride_request_id, screen: "home" },
        priority: "high",
        channel: "both",
      };
      return await deliverNotification(supabase, notification, manual);
    }

    if (
      manual?.event === "favorite_added" &&
      (manual as FavoriteAddedPayload).notification_id
    ) {
      const fav = manual as FavoriteAddedPayload;

      // Auth: webhook secret or service-role (RPC calls via net.http_post)
      if (WEBHOOK_SECRET) {
        const incomingSecret = req.headers.get("x-webhook-secret") ?? "";
        const valid = await safeCompare(incomingSecret, WEBHOOK_SECRET);
        if (!valid) {
          return json({ error: "Unauthorized" }, 401);
        }
      }

      // Notification already inserted by fn_rider_add_favorite_driver RPC.
      // Just send FCM push to the driver's registered devices.
      const { data: pushRows } = await supabase
        .from("push_devices")
        .select("fcm_token")
        .eq("driver_id", fav.driver_id)
        .eq("app_role", "driver");

      let pushed = 0;
      for (const row of pushRows ?? []) {
        const token = row?.fcm_token as string | null;
        if (!token || token.length < 10) continue;
        await sendFcmNotification(token, {
          title: fav.title,
          body: fav.body,
          data: {
            ...(fav.data ?? {}),
            notification_id: fav.notification_id,
            category: "favorite_added",
          },
          priority: fav.priority ?? "medium",
        });
        pushed++;
      }

      // Mark push_sent_at on the notification row
      await supabase
        .from("notifications")
        .update({ push_sent_at: new Date().toISOString() })
        .eq("id", fav.notification_id);

      return json({ ok: true, pushed });
    }

    // Webhook fallback path — requires WEBHOOK_SECRET
    if (!WEBHOOK_SECRET) {
      console.error(
        "AGENT_WEBHOOK_SECRET env var not set — rejecting webhook request",
      );
      return json({ error: "Misconfigured" }, 500);
    }

    const incomingSecret = req.headers.get("x-webhook-secret") ?? "";
    const valid = await safeCompare(incomingSecret, WEBHOOK_SECRET);
    if (!valid) {
      console.warn(
        "driver-agent: rejected request with invalid webhook secret",
      );
      return json({ error: "Unauthorized" }, 401);
    }

    const payload = body as WebhookPayload;
    const { table, type, record } = payload;
    if (!table || !type || !record) {
      return json({ error: "Missing table/type/record" }, 400);
    }

    const notification = buildAgentNotification(payload);
    if (!notification) {
      console.log(
        "driver-agent: no notification for",
        payload.type,
        payload.table,
        "status=",
        payload.record?.status,
        "old_status=",
        payload.old_record?.status,
        "driver_id=",
        payload.record?.driver_id,
        "rider_identity_id=",
        payload.record?.rider_identity_id,
      );
      await supabase.from("agent_logs").insert({
        agent: "driver_agent",
        event_type: `${payload.table}_${payload.type}_skipped`,
        input: payload,
        output: { reason: "no_notification_built" },
      });
      return ok();
    }

    const enrichedNotification = await enrichInviteNotification(
      supabase,
      payload,
      notification,
    );

    return await deliverNotification(supabase, enrichedNotification, payload);
  } catch (e) {
    console.error("driver-agent error:", e);
    return json({ error: String(e) }, 500);
  }
});
