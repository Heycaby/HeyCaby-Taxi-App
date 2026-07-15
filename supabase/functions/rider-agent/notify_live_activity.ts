import type { SupabaseClient } from "jsr:@supabase/supabase-js";

import { sendFcmLiveActivityUpdate } from "./fcm_v1.ts";

type RideRow = {
  id: string;
  status: string | null;
  destination_address: string | null;
  driver_arrived_at: string | null;
  waiting_grace_seconds: number | null;
  waiting_fee_cents: number | null;
  waiting_fee_waived: boolean | null;
  payment_status: string | null;
  estimated_duration_min: number | null;
  updated_at: string | null;
};

function rideIdFrom(data: Record<string, unknown>): string | null {
  for (const key of ["ride_request_id", "ride_id"]) {
    const value = data[key];
    if (typeof value === "string" && value.length > 10) return value;
  }
  return null;
}

export function contentFor(
  ride: RideRow,
  category: string,
  title: string,
  body: string,
): { state: Record<string, unknown>; event: "update" | "end"; alert: boolean } {
  const status = (ride.status ?? "").toLowerCase();
  const payment = (ride.payment_status ?? "").toLowerCase();
  const terminal = [
    "cancelled",
    "canceled",
    "rejected",
    "declined",
    "missed",
    "expired",
  ].includes(status);
  const paid = payment === "confirmed" || payment === "paid" ||
    category === "payment_confirmed";
  const completed = status === "completed" || category.includes("completed");
  const arrived = status === "driver_arrived" || status === "arrived" ||
    category.includes("arrived") || category.includes("outside");
  const nearby = category.includes("near");
  const onTrip = status === "in_progress" ||
    category.includes("trip_started") || category.includes("ride_started");
  const onWay = status === "driver_en_route" ||
    category.includes("on_my_way") || category.includes("en_route");

  let phase = "driver_found";
  let progressPercent = 35;
  let nextAction = "Meet your driver at the pickup point.";
  let eta = "";
  let heroMetric = "Found";
  let compactTrailing = "Found";
  let waitPhase = "none";
  let graceRemaining = "";
  let graceEndsAtEpoch: number | null = null;
  let waitFee = "";

  if (paid) {
    phase = "completed";
    progressPercent = 100;
    heroMetric = "✓";
    compactTrailing = "Done";
    nextAction = "Thank you for riding with HeyCaby.";
  } else if (completed) {
    phase = "payment";
    progressPercent = 96;
    heroMetric = "Pay";
    compactTrailing = "Pay";
    nextAction = "Confirm payment with your driver.";
  } else if (onTrip) {
    phase = "on_trip";
    progressPercent = 78;
    const minutes = Math.max(1, Number(ride.estimated_duration_min ?? 0));
    eta = minutes > 0 ? `${minutes} min` : "";
    heroMetric = eta;
    compactTrailing = eta || "Trip";
    nextAction = "Relax — we'll keep you updated.";
  } else if (arrived) {
    phase = "outside_free";
    progressPercent = 62;
    waitPhase = "free";
    const arrivedMs = Date.parse(ride.driver_arrived_at ?? "");
    const grace = Math.max(0, Number(ride.waiting_grace_seconds ?? 120));
    if (Number.isFinite(arrivedMs)) {
      graceEndsAtEpoch = Math.floor(arrivedMs / 1000) + grace;
      const remaining = Math.max(
        0,
        graceEndsAtEpoch - Math.floor(Date.now() / 1000),
      );
      graceRemaining = `${Math.floor(remaining / 60)}:${
        String(remaining % 60).padStart(2, "0")
      }`;
      if (remaining === 0 && !ride.waiting_fee_waived) {
        phase = "outside_paid";
        waitPhase = "paid";
        const cents = Math.max(0, Number(ride.waiting_fee_cents ?? 0));
        waitFee = cents > 0
          ? `€${(cents / 100).toFixed(2)} added`
          : "Waiting fee active";
      }
    }
    heroMetric = waitPhase === "free" ? (graceRemaining || "Outside") : waitFee;
    compactTrailing = waitPhase === "free" ? `${graceRemaining} free` : "Wait";
    nextAction = "Please join your driver at the pickup point.";
  } else if (nearby) {
    phase = "nearby";
    progressPercent = 52;
    heroMetric = "Nearby";
    compactTrailing = "Near";
    nextAction = "Please head downstairs to avoid waiting fees.";
  } else if (onWay) {
    phase = "on_the_way";
    progressPercent = 45;
    compactTrailing = "En route";
    nextAction = "Your driver is heading to you.";
  }

  const version = ride.updated_at ? Date.parse(ride.updated_at) : Date.now();
  return {
    event: terminal || paid ? "end" : "update",
    alert: nearby || arrived || category.includes("ping"),
    state: {
      appGroupId: "group.nl.heycaby.rider.app.widgets",
      phase,
      title,
      subtitle: ride.destination_address ?? "",
      status: body,
      nextAction,
      eta,
      progressPercent,
      graceRemaining,
      graceEndsAtEpoch,
      waitFee,
      heroMetric,
      compactTrailing,
      waitPhase,
      rideVersion: Number.isFinite(version) ? version : Date.now(),
    },
  };
}

export async function deliverLiveActivityUpdate(
  supabase: SupabaseClient,
  notification: {
    category: string;
    title: string;
    body: string;
    data: Record<string, unknown>;
  },
): Promise<number> {
  const rideId = rideIdFrom(notification.data ?? {});
  if (!rideId) return 0;

  const [{ data: ride }, { data: activities }] = await Promise.all([
    supabase.from("ride_requests").select(
      "id,status,destination_address,driver_arrived_at,waiting_grace_seconds,waiting_fee_cents,waiting_fee_waived,payment_status,estimated_duration_min,updated_at",
    ).eq("id", rideId).maybeSingle(),
    supabase.from("rider_live_activities").select(
      "id,fcm_token,activity_push_token,last_event_version",
    ).eq("ride_request_id", rideId).eq("is_active", true),
  ]);
  if (!ride || !activities?.length) return 0;

  const payload = contentFor(
    ride as RideRow,
    notification.category,
    notification.title,
    notification.body,
  );
  const version = Number(payload.state.rideVersion ?? Date.now());
  let pushed = 0;
  for (const activity of activities) {
    if (version < Number(activity.last_event_version ?? 0)) continue;
    const sent = await sendFcmLiveActivityUpdate({
      fcmToken: activity.fcm_token,
      activityToken: activity.activity_push_token,
      event: payload.event,
      contentState: payload.state,
      title: payload.alert ? notification.title : undefined,
      body: payload.alert ? notification.body : undefined,
      staleDate: Math.floor(Date.now() / 1000) + 180,
      dismissalDate: payload.event === "end"
        ? Math.floor(Date.now() / 1000) + 60
        : undefined,
    });
    await supabase.from("rider_live_activities").update({
      is_active: sent.ok && payload.event === "end" ? false : true,
      last_event_version: version,
      last_pushed_at: sent.ok ? new Date().toISOString() : null,
      last_error: sent.ok ? null : sent.error,
      updated_at: new Date().toISOString(),
    }).eq("id", activity.id);
    if (sent.ok) pushed++;
  }
  return pushed;
}
