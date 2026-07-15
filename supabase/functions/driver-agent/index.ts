// Driver Agent — transactional push via FCM HTTP v1 + rider pre-ride nudges.
// Triggered by DB webhooks (ride_requests, messages, ride_ratings) or
// POST { event: "preride_request", ride_request_id } with x-webhook-secret
// or Authorization: Bearer <driver JWT>.

import {
  createClient,
  resolveWebhookSecret,
  serviceRoleKey,
  supabaseUrl,
} from "./config.ts";
import { buildAgentNotification } from "./notify_rules.ts";
import type {
  AgentNotificationRow,
  FavoriteAddedPayload,
  ManualDriverPingPayload,
  ManualPreridePayload,
  TaxiTerugOfferIncreasedPayload,
  WebhookPayload,
} from "./notify_types.ts";
import {
  authorizeManualPreride,
  deliverNotification,
} from "./notify_deliver.ts";
import { sendPushNotification } from "./notify_push.ts";
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

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function euroAmount(value: number): string {
  return Number.isInteger(value)
    ? value.toFixed(0)
    : value.toFixed(2).replace(/0+$/, "").replace(/\.$/, "");
}

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
    const webhookSecret = await resolveWebhookSecret();

    const manual = body as
      | ManualPreridePayload
      | ManualDriverPingPayload
      | FavoriteAddedPayload
      | TaxiTerugOfferIncreasedPayload;

    if (manual?.event === "taxi_terug_offer_increased") {
      const offer = manual as TaxiTerugOfferIncreasedPayload;
      if (!webhookSecret) {
        return json({ error: "Misconfigured" }, 500);
      }
      const incomingSecret = req.headers.get("x-webhook-secret") ?? "";
      if (!(await safeCompare(incomingSecret, webhookSecret))) {
        return json({ error: "Unauthorized" }, 401);
      }

      const previousFare = Number(offer.previous_fare);
      const newFare = Number(offer.new_fare);
      const increase = Number(offer.increase);
      if (
        !uuidPattern.test(offer.ride_request_id ?? "") ||
        !uuidPattern.test(offer.source_event_id ?? "") ||
        !Number.isFinite(previousFare) ||
        !Number.isFinite(newFare) ||
        !Number.isFinite(increase) ||
        newFare <= previousFare ||
        Math.abs(newFare - previousFare - increase) > 0.004
      ) {
        return json({ error: "invalid_taxi_terug_offer_event" }, 400);
      }

      const { data: ride, error: rideError } = await supabase
        .from("ride_requests")
        .select(
          "booking_mode, status, driver_id, expires_at, marketplace_offered_fare",
        )
        .eq("id", offer.ride_request_id)
        .maybeSingle();
      const rideExpiry = ride?.expires_at
        ? Date.parse(ride.expires_at as string)
        : Number.NaN;
      const currentFare = Number(ride?.marketplace_offered_fare);
      if (
        rideError ||
        !ride ||
        ride.booking_mode !== "terug" ||
        !["pending", "bidding"].includes(ride.status as string) ||
        ride.driver_id ||
        (Number.isFinite(rideExpiry) && rideExpiry <= Date.now()) ||
        !Number.isFinite(currentFare) ||
        Math.abs(currentFare - newFare) > 0.004
      ) {
        return json({
          ok: true,
          skipped: true,
          reason: "taxi_terug_offer_not_live",
        });
      }

      const { data: inviteRows, error: inviteError } = await supabase
        .from("ride_request_invites")
        .select("driver_id")
        .eq("ride_request_id", offer.ride_request_id)
        .eq("status", "pending")
        .gt("expires_at", new Date().toISOString());
      if (inviteError) {
        console.error(
          "driver-agent: Taxi Terug offer audience lookup failed",
          inviteError.code,
        );
        return json({ error: "audience_lookup_failed" }, 500);
      }

      const driverIds = [
        ...new Set(
          (inviteRows ?? [])
            .map((row) => row.driver_id as string | null)
            .filter((id): id is string => !!id),
        ),
      ];
      let eligible = 0;
      let delivered = 0;
      let failed = 0;

      for (const driverId of driverIds) {
        const { data: qualification, error: qualificationError } =
          await supabase.rpc("fn_terugtaxi_qualify", {
            p_driver_id: driverId,
            p_ride_request_id: offer.ride_request_id,
          });
        if (
          qualificationError ||
          !(qualification as Record<string, unknown> | null)?.qualified
        ) continue;
        eligible += 1;

        const response = await deliverNotification(supabase, {
          target: "driver",
          user_type: "driver",
          user_id: driverId,
          agent: "driver_agent",
          category: "taxi_terug_offer_increased",
          title: "Taxi Terug offer increased",
          body: `The Rider increased the offer by €${
            euroAmount(increase)
          }.\nNew offer: €${euroAmount(newFare)}.`,
          data: {
            source_event_id: offer.source_event_id,
            ride_request_id: offer.ride_request_id,
            booking_mode: "terug",
            previous_fare: previousFare,
            new_fare: newFare,
            increase,
            screen: "taxi_thru",
            notification_type: "taxi_terug_offer_increased",
          },
          priority: "high",
          channel: "both",
        }, offer);
        if (response.ok) {
          delivered += 1;
        } else {
          failed += 1;
        }
      }

      return json({
        ok: true,
        source_event_id: offer.source_event_id,
        audience_count: driverIds.length,
        eligible_count: eligible,
        delivered_count: delivered,
        failed_count: failed,
      });
    }

    if (manual?.event === "driver_ping" && manual.ride_request_id) {
      const ping = manual as ManualDriverPingPayload;
      const kind = normalizePingKind(ping.kind);
      if (!kind) return json({ error: "invalid_ping_kind" }, 400);

      const authorized = await authorizeManualPreride(
        req,
        ping.ride_request_id,
        webhookSecret,
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
        ![
          "accepted",
          "assigned",
          "driver_found",
          "driver_en_route",
          "driver_arrived",
          "arrived",
          "in_progress",
        ].includes(rideStatus)
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
        webhookSecret,
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
      if (webhookSecret) {
        const incomingSecret = req.headers.get("x-webhook-secret") ?? "";
        const valid = await safeCompare(incomingSecret, webhookSecret);
        if (!valid) {
          return json({ error: "Unauthorized" }, 401);
        }
      }

      // Notification already inserted by fn_rider_add_favorite_driver RPC.
      // Just send FCM push to the driver's registered devices.
      const { data: pushRows } = await supabase
        .from("push_devices")
        .select(
          "id, fcm_token, apns_token, apns_environment, platform, app_role",
        )
        .eq("driver_id", fav.driver_id)
        .eq("app_role", "driver");

      let pushed = 0;
      let failed = 0;
      let invalidTokensRemoved = 0;
      const pushErrorCodes = new Set<string>();
      const pushProviders = new Set<string>();
      for (const row of pushRows ?? []) {
        const token = row?.fcm_token as string | null;
        const apnsToken = row?.apns_token as string | null;
        if (
          (!token || token.length < 10) &&
          (!apnsToken || apnsToken.length < 10)
        ) continue;
        const result = await sendPushNotification(
          {
            fcm_token: token,
            apns_token: apnsToken,
            apns_environment: row?.apns_environment as string | null,
            platform: row?.platform as string,
            app_role: row?.app_role as string,
          },
          {
            title: fav.title,
            body: fav.body,
            data: {
              ...(fav.data ?? {}),
              notification_id: fav.notification_id,
              category: "favorite_added",
            },
            priority: fav.priority ?? "medium",
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
        if (result.provider) pushProviders.add(result.provider);
        if (result.errorCode) pushErrorCodes.add(result.errorCode);
        if (result.invalidApnsToken && row?.id) {
          invalidTokensRemoved++;
          await supabase.from("push_devices").update({
            apns_token: null,
            apns_environment: null,
            updated_at: new Date().toISOString(),
          }).eq("id", row.id);
        }
        if (result.ok) {
          pushed++;
        } else {
          failed++;
          if (result.permanentFailure && !result.invalidApnsToken && row?.id) {
            await supabase.from("push_devices").delete().eq("id", row.id);
            invalidTokensRemoved++;
          }
        }
      }

      // Mark push_sent_at on the notification row
      if (pushed > 0) {
        await supabase
          .from("notifications")
          .update({ push_sent_at: new Date().toISOString() })
          .eq("id", fav.notification_id);
      }

      return json({
        ok: true,
        pushed,
        failed,
        invalid_tokens_removed: invalidTokensRemoved,
        push_providers: [...pushProviders],
        push_error_codes: [...pushErrorCodes],
      });
    }

    // Webhook fallback path — requires WEBHOOK_SECRET
    if (!webhookSecret) {
      console.error(
        "driver-agent webhook secret unavailable — rejecting webhook request",
      );
      return json({ error: "Misconfigured" }, 500);
    }

    const incomingSecret = req.headers.get("x-webhook-secret") ?? "";
    const valid = await safeCompare(incomingSecret, webhookSecret);
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
