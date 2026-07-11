import type { SupabaseClient } from 'jsr:@supabase/supabase-js'

import type { RiderNotificationRow } from './notify_types.ts'
import { resolveRiderFcmTokens } from './resolve_fcm_tokens.ts'
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

  const fcmTokens = await resolveRiderFcmTokens(supabase, notification)

  let pushed = 0
  for (const token of fcmTokens) {
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
