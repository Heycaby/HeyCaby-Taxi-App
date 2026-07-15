import type { SupabaseClient } from "jsr:@supabase/supabase-js";

import type { AgentNotificationRow } from "./notify_types.ts";

export type IncomingRideGate =
  | { live: true; expiresAt?: string }
  | { live: false; reason: string };

/**
 * Final authoritative liveness check for an incoming-ride notification.
 *
 * This runs before the notification row is written and again immediately
 * before provider delivery. It deliberately reads current database state
 * rather than trusting a delayed webhook payload.
 */
export async function incomingRideGate(
  supabase: SupabaseClient,
  notification: AgentNotificationRow,
): Promise<IncomingRideGate> {
  if (notification.category !== "incoming_ride") return { live: true };

  const inviteId = (notification.data?.ride_invite_id ??
    notification.data?.invite_id) as string | undefined;
  const rideRequestId = notification.data?.ride_request_id as
    | string
    | undefined;
  if (!inviteId || !rideRequestId) {
    return { live: false, reason: "invite_identity_missing" };
  }

  const { data: invite, error: inviteError } = await supabase
    .from("ride_request_invites")
    .select("id, ride_request_id, driver_id, status, expires_at")
    .eq("id", inviteId)
    .eq("ride_request_id", rideRequestId)
    .maybeSingle();
  if (inviteError || !invite) {
    return { live: false, reason: "invite_missing" };
  }
  if (invite.driver_id !== notification.user_id) {
    return { live: false, reason: "invite_recipient_changed" };
  }
  if (invite.status !== "pending") {
    return { live: false, reason: "invite_not_pending" };
  }
  const inviteExpiresAt = Date.parse(invite.expires_at as string);
  if (!Number.isFinite(inviteExpiresAt) || inviteExpiresAt <= Date.now()) {
    return { live: false, reason: "invite_expired" };
  }

  const { data: ride, error: rideError } = await supabase
    .from("ride_requests")
    .select("status, driver_id, expires_at")
    .eq("id", rideRequestId)
    .maybeSingle();
  if (rideError || !ride) {
    return { live: false, reason: "ride_missing" };
  }
  if (!["pending", "bidding"].includes(ride.status as string)) {
    return { live: false, reason: "ride_not_open" };
  }
  if (ride.driver_id) {
    return { live: false, reason: "ride_already_assigned" };
  }
  let deliveryExpiresAt = inviteExpiresAt;
  if (ride.expires_at) {
    const rideExpiresAt = Date.parse(ride.expires_at as string);
    if (Number.isFinite(rideExpiresAt) && rideExpiresAt <= Date.now()) {
      return { live: false, reason: "ride_expired" };
    }
    if (Number.isFinite(rideExpiresAt)) {
      deliveryExpiresAt = Math.min(deliveryExpiresAt, rideExpiresAt);
    }
  }

  return { live: true, expiresAt: new Date(deliveryExpiresAt).toISOString() };
}

async function taxiTerugOfferGate(
  supabase: SupabaseClient,
  notification: AgentNotificationRow,
): Promise<IncomingRideGate> {
  if (notification.category !== "taxi_terug_offer_increased") {
    return { live: true };
  }

  const rideRequestId = notification.data?.ride_request_id as
    | string
    | undefined;
  const expectedFare = Number(notification.data?.new_fare);
  if (!rideRequestId || !Number.isFinite(expectedFare)) {
    return { live: false, reason: "offer_identity_missing" };
  }

  const { data: ride, error } = await supabase
    .from("ride_requests")
    .select(
      "booking_mode, status, driver_id, expires_at, marketplace_offered_fare",
    )
    .eq("id", rideRequestId)
    .maybeSingle();
  if (error || !ride) return { live: false, reason: "ride_missing" };
  if (ride.booking_mode !== "terug") {
    return { live: false, reason: "not_taxi_terug" };
  }
  if (!["pending", "bidding"].includes(ride.status as string)) {
    return { live: false, reason: "ride_not_open" };
  }
  if (ride.driver_id) {
    return { live: false, reason: "ride_already_assigned" };
  }
  if (ride.expires_at) {
    const rideExpiresAt = Date.parse(ride.expires_at as string);
    if (Number.isFinite(rideExpiresAt) && rideExpiresAt <= Date.now()) {
      return { live: false, reason: "ride_expired" };
    }
  }
  const currentFare = Number(ride.marketplace_offered_fare);
  if (
    !Number.isFinite(currentFare) ||
    Math.abs(currentFare - expectedFare) > 0.004
  ) {
    return { live: false, reason: "offer_superseded" };
  }
  return { live: true };
}

/** Revalidates every time-sensitive notification against current DB truth. */
export async function notificationDeliveryGate(
  supabase: SupabaseClient,
  notification: AgentNotificationRow,
): Promise<IncomingRideGate> {
  const incoming = await incomingRideGate(supabase, notification);
  if (!incoming.live || notification.category === "incoming_ride") {
    return incoming;
  }
  return await taxiTerugOfferGate(supabase, notification);
}
