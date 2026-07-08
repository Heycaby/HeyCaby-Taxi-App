import type { SupabaseClient } from 'jsr:@supabase/supabase-js'

import { sendFcmV1ToToken } from './fcm_v1.ts'

/** Sends one notification via FCM HTTP v1 (native iOS/Android tokens only). */
export async function sendFcmNotification(
  fcmToken: string | null,
  notification: {
    title: string
    body: string | null
    data?: Record<string, unknown>
    priority?: string
    androidChannelId?: string
  },
): Promise<void> {
  if (!fcmToken || fcmToken.length < 10) return
  const channelFromData = notification.data?.android_channel_id as string | undefined
  await sendFcmV1ToToken(fcmToken, {
    ...notification,
    androidChannelId: notification.androidChannelId ?? channelFromData,
  })
}
