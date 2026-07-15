import type { SupabaseClient } from "jsr:@supabase/supabase-js";

import { type FcmSendResult, sendFcmV1ToToken } from "./fcm_v1.ts";

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
