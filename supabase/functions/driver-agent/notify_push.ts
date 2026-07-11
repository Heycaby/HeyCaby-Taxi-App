import type { SupabaseClient } from "jsr:@supabase/supabase-js";

import {
  type FcmSendResult,
  sendFcmV1ToToken,
} from "./fcm_v1.ts";

export async function getDriverIdForRideRequest(
  supabase: SupabaseClient,
  rideRequestId: string,
): Promise<string | null> {
  const { data } = await supabase.from("ride_requests").select("driver_id").eq(
    "id",
    rideRequestId,
  ).single();
  return (data?.driver_id as string) ?? null;
}

/** Sends one notification via FCM HTTP v1 (native iOS/Android tokens only). */
export async function sendFcmNotification(
  fcmToken: string | null,
  notification: {
    title: string;
    body: string | null;
    data?: Record<string, unknown>;
    priority?: string;
    androidChannelId?: string;
  },
): Promise<FcmSendResult> {
  if (!fcmToken || fcmToken.length < 10) {
    return {
      ok: false,
      permanentFailure: true,
      errorCode: "invalid_local_token",
    };
  }
  const channelFromData = notification.data?.android_channel_id as
    | string
    | undefined;
  return await sendFcmV1ToToken(fcmToken, {
    ...notification,
    androidChannelId: notification.androidChannelId ?? channelFromData,
  });
}

export async function recentPrerideNotification(
  supabase: SupabaseClient,
  rideRequestId: string,
): Promise<boolean> {
  const since = new Date(Date.now() - 120_000).toISOString();
  const { data, error } = await supabase
    .from("notifications")
    .select("id")
    .eq("category", "preride_request")
    .contains("data", { ride_request_id: rideRequestId })
    .gte("created_at", since)
    .limit(1);
  if (error) return false;
  return (data?.length ?? 0) > 0;
}
