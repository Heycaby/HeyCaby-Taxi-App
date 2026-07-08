import type { SupabaseClient } from 'jsr:@supabase/supabase-js'

import type { RiderNotificationRow } from './notify_types.ts'
import { sendFcmNotification } from './notify_push.ts'

export async function deliverNotification(
  supabase: SupabaseClient,
  notification: RiderNotificationRow,
): Promise<Response> {
  // Insert notification into database
  const { data: inserted, error: insertError } = await supabase
    .from('notifications')
    .insert({
      user_type: notification.user_type,
      user_id: notification.user_id,
      agent: notification.agent,
      category: notification.category,
      title: notification.title,
      body: notification.body,
      data: notification.data,
      priority: notification.priority,
      channel: notification.channel,
    })
    .select('id')
    .single()

  if (insertError || !inserted) {
    console.error('Failed to insert notification:', insertError)
    return new Response(JSON.stringify({ error: 'insert_failed' }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  const notificationId = inserted.id as string

  // Send FCM push to rider devices
  const { data: pushRows } = await supabase
    .from('push_devices')
    .select('fcm_token')
    .eq('rider_identity_id', notification.user_id)
    .eq('app_role', 'rider')

  let pushed = 0
  for (const row of pushRows ?? []) {
    const token = row?.fcm_token as string | null
    if (!token || token.length < 10) continue
    await sendFcmNotification(token, {
      title: notification.title,
      body: notification.body,
      data: notification.data,
      priority: notification.priority,
    })
    pushed++
  }

  // Mark push_sent_at on the notification row
  await supabase
    .from('notifications')
    .update({ push_sent_at: new Date().toISOString() })
    .eq('id', notificationId)

  return new Response(JSON.stringify({ ok: true, pushed, notification_id: notificationId }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  })
}
