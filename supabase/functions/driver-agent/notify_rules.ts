import type { AgentNotificationRow, WebhookPayload } from "./notify_types.ts";

export function buildAgentNotification(
  payload: WebhookPayload,
): AgentNotificationRow | null {
  const { type, table, record, old_record } = payload;

  if (table === "ride_requests") {
    const driverId = record?.driver_id as string | undefined;
    const status = record?.status as string | undefined;
    const oldStatus = old_record?.status as string | undefined;
    const isMarket = record?.is_market === true;
    const isScheduled = record?.is_scheduled === true;
    const rideRequestId = record?.id as string | undefined;

    if (type === "UPDATE" && rideRequestId) {
      if (
        status === "accepted" &&
        oldStatus !== "accepted"
      ) {
        const riderIdentityId = record?.rider_identity_id as string | undefined;
        if (riderIdentityId) {
          return {
            target: "rider",
            user_type: "rider",
            user_id: riderIdentityId,
            agent: "driver_agent",
            category: "driver_found",
            title: "Driver found",
            body: "Your driver accepted the ride.",
            data: {
              ride_request_id: rideRequestId,
              screen: "active",
              notification_type: "driver_found",
            },
            priority: "high",
            channel: "both",
          };
        }
      }

      if (
        status === "driver_en_route" &&
        oldStatus !== "driver_en_route"
      ) {
        const riderIdentityId = record?.rider_identity_id as string | undefined;
        if (riderIdentityId) {
          return {
            target: "rider",
            user_type: "rider",
            user_id: riderIdentityId,
            agent: "driver_agent",
            category: "driver_en_route",
            title: "Driver on the way",
            body: "Your driver is heading to your pickup.",
            data: {
              ride_request_id: rideRequestId,
              screen: "active",
              notification_type: "driver_en_route",
            },
            priority: "high",
            channel: "both",
          };
        }
      }

      if (
        status === "driver_arrived" &&
        oldStatus !== "driver_arrived"
      ) {
        const riderIdentityId = record?.rider_identity_id as string | undefined;
        if (riderIdentityId) {
          return {
            target: "rider",
            user_type: "rider",
            user_id: riderIdentityId,
            agent: "driver_agent",
            category: "driver_ping_arrived",
            title: "Driver has arrived",
            body: "Your driver is at the pickup point.",
            data: {
              ride_request_id: rideRequestId,
              screen: "active",
              ping_kind: "arrived",
              notification_type: "driver_arrived",
            },
            priority: "high",
            channel: "both",
          };
        }
      }

      if (
        status === "in_progress" &&
        oldStatus !== "in_progress"
      ) {
        const riderIdentityId = record?.rider_identity_id as string | undefined;
        if (riderIdentityId) {
          return {
            target: "rider",
            user_type: "rider",
            user_id: riderIdentityId,
            agent: "driver_agent",
            category: "trip_started",
            title: "Trip started",
            body: "Your ride is now in progress.",
            data: {
              ride_request_id: rideRequestId,
              screen: "active",
              notification_type: "trip_started",
            },
            priority: "medium",
            channel: "both",
          };
        }
      }

      const oldSent = old_record?.rider_preride_request_sent_at;
      const newSent = record?.rider_preride_request_sent_at;
      if (!oldSent && newSent) {
        const riderIdentityId = record?.rider_identity_id as string | undefined;
        if (riderIdentityId) {
          return {
            target: "rider",
            user_type: "rider",
            user_id: riderIdentityId,
            agent: "driver_agent",
            category: "preride_request",
            title: "Bevestig je rit",
            body: "Je chauffeur vraagt je rit te bevestigen vóór de rit.",
            data: { ride_request_id: rideRequestId, screen: "home" },
            priority: "high",
            channel: "both",
          };
        }
      }
    }

    if (type === "INSERT") {
      if (driverId) {
        return {
          target: "driver",
          user_type: "driver",
          user_id: driverId,
          agent: "driver_agent",
          category: "incoming_ride",
          title: "🚨 New ride request — 15 sec to accept",
          body: null,
          data: {
            ride_request_id: rideRequestId,
            screen: "incoming",
            android_channel_id: "incoming_ride_channel",
            notification_type: "incoming_ride",
          },
          priority: "critical",
          channel: "both",
        };
      }
      if (isMarket || isScheduled) return null;
      return null;
    }

    if (type === "UPDATE" && driverId) {
      if (status === "cancelled" && oldStatus !== "cancelled") {
        const cancelledBy = record?.cancelled_by as string | undefined;
        if (cancelledBy === "driver") {
          const riderIdentityId = record?.rider_identity_id as
            | string
            | undefined;
          if (riderIdentityId) {
            return {
              target: "rider",
              user_type: "rider",
              user_id: riderIdentityId,
              agent: "driver_agent",
              category: "ride_cancelled",
              title: "Driver cancelled the ride",
              body: "Your ride was cancelled by the driver.",
              data: {
                ride_request_id: rideRequestId,
                screen: "home",
                notification_type: "driver_cancelled",
              },
              priority: "high",
              channel: "both",
            };
          }
          return null;
        }
        return {
          target: "driver",
          user_type: "driver",
          user_id: driverId,
          agent: "driver_agent",
          category: "ride_phase",
          title: "⚠️ Rider cancelled the ride",
          body: null,
          data: { ride_request_id: rideRequestId },
          priority: "high",
          channel: "both",
        };
      }
    }
    return null;
  }

  if (table === "ride_request_invites" && type === "INSERT") {
    const status = record?.status as string | undefined;
    if (status && status !== "pending") return null;

    const rideRequestId = record?.ride_request_id as string | undefined;
    const rideInviteId = record?.id as string | undefined;
    const driverId = record?.driver_id as string | undefined;
    if (!rideRequestId || !driverId) return null;
    const expiresAt = typeof record?.expires_at === "string"
      ? Date.parse(record.expires_at)
      : Number.NaN;
    if (Number.isFinite(expiresAt) && expiresAt <= Date.now()) return null;

    return {
      target: "driver",
      user_type: "driver",
      user_id: driverId,
      agent: "driver_agent",
      category: "incoming_ride",
      title: "New ride request",
      body: "A rider nearby is looking for a taxi",
      data: {
        ride_request_id: rideRequestId,
        ride_invite_id: rideInviteId,
        invite_id: rideInviteId,
        screen: "incoming_ride",
        expires_at: record?.expires_at ?? null,
        android_channel_id: "incoming_ride_channel",
        notification_type: "incoming_ride",
      },
      priority: "critical",
      channel: "both",
    };
  }

  if (
    (table === "messages" || table === "ride_messages") && type === "INSERT"
  ) {
    const senderType = record?.sender_type as string | undefined;
    const rideRequestId = record?.ride_request_id as string | undefined;
    if (!rideRequestId) return null;
    const content = (record?.content as string) || (record?.body as string) ||
      "";
    const preview = content.length > 60
      ? content.slice(0, 57) + "..."
      : content;

    // Rider → Driver chat message
    if (senderType === "rider") {
      return {
        target: "driver",
        user_type: "driver",
        user_id: "",
        agent: "driver_agent",
        category: "chat",
        title: "Rider message",
        body: preview,
        data: {
          ride_request_id: rideRequestId,
          screen: "chat",
          notification_type: "ride_signal",
          signal_kind: "rider_message",
          message_id: record?.id ?? null,
        },
        priority: "medium",
        channel: "both",
      };
    }

    // Driver → Rider chat message
    if (senderType === "driver") {
      // Look up rider_identity_id from the ride request
      const oldRiderIdentityId = record?.rider_identity_id as
        | string
        | undefined;
      if (oldRiderIdentityId) {
        return {
          target: "rider",
          user_type: "rider",
          user_id: oldRiderIdentityId,
          agent: "driver_agent",
          category: "chat",
          title: "Driver message",
          body: preview,
          data: {
            ride_request_id: rideRequestId,
            screen: "chat",
            notification_type: "ride_signal",
            signal_kind: "driver_message",
            message_id: record?.id ?? null,
          },
          priority: "medium",
          channel: "both",
        };
      }
      // Fallback: deliverNotification will resolve rider_identity_id from ride_requests
      return {
        target: "rider",
        user_type: "rider",
        user_id: "",
        agent: "driver_agent",
        category: "chat",
        title: "💬 [Driver]: " + preview,
        body: preview,
        data: { ride_request_id: rideRequestId, screen: "chat" },
        priority: "medium",
        channel: "both",
      };
    }

    return null;
  }

  if (table === "ride_ratings" && (type === "UPDATE" || type === "INSERT")) {
    const rideRequestId = record?.ride_request_id as string | undefined;
    if (!rideRequestId) return null;

    const oldRiderRating = old_record?.rider_rating_of_driver;
    const newRiderRating = record?.rider_rating_of_driver;
    const oldDriverRating = old_record?.driver_rating_of_rider;
    const newDriverRating = record?.driver_rating_of_rider;

    if (
      newRiderRating != null &&
      newRiderRating !== oldRiderRating
    ) {
      return {
        target: "driver",
        user_type: "driver",
        user_id: "",
        agent: "driver_agent",
        category: "rating",
        title: "⭐ You received a new rating",
        body: "A rider left feedback on your trip.",
        data: { ride_request_id: rideRequestId, screen: "score" },
        priority: "low",
        channel: "both",
      };
    }

    if (
      newDriverRating != null &&
      newDriverRating !== oldDriverRating
    ) {
      return {
        target: "rider",
        user_type: "rider",
        user_id: "",
        agent: "driver_agent",
        category: "rating",
        title: "⭐ You received a new rating",
        body: "Your driver left feedback about your trip.",
        data: { ride_request_id: rideRequestId, screen: "account" },
        priority: "low",
        channel: "both",
      };
    }
  }

  return null;
}
