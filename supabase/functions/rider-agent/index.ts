// Rider Agent — processes rider notifications and sends FCM pushes.
// Triggered by DB webhooks on notifications table or POST with notification_id.

import { createClient } from 'jsr:@supabase/supabase-js@2'

import {
  supabaseUrl,
  serviceRoleKey,
  WEBHOOK_SECRET,
} from './config.ts'
import type { RiderNotificationRow } from './notify_types.ts'
import { deliverNotification } from './notify_deliver.ts'
import { deliverLiveActivityUpdate } from './notify_live_activity.ts'
import { resolveRiderFcmTokens } from './resolve_fcm_tokens.ts'
import { json, ok, safeCompare } from './util.ts'

async function webhookSecret(supabase: ReturnType<typeof createClient>): Promise<string> {
  if (WEBHOOK_SECRET) return WEBHOOK_SECRET
  const { data } = await supabase.rpc('fn_rider_agent_webhook_secret')
  return typeof data === 'string' ? data : ''
}

Deno.serve(async (req) => {
  try {
    if (req.method === 'OPTIONS') return ok()

    const raw = await req.text()
    let body: unknown
    try {
      body = JSON.parse(raw)
    } catch {
      return json({ error: 'Invalid JSON' }, 400)
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    })

    // Check if this is a webhook from notifications table
    const webhook = body as { table?: string; type?: string; record?: { agent?: string; push_sent_at?: string | null; id?: string } }
    if (webhook?.table === 'notifications' && webhook?.type === 'INSERT') {
      const expectedSecret = await webhookSecret(supabase)
      if (expectedSecret) {
        const incomingSecret = req.headers.get('x-webhook-secret') ?? ''
        if (!await safeCompare(incomingSecret, expectedSecret)) {
          return json({ error: 'Unauthorized' }, 401)
        }
      }
      const record = webhook.record
      // Lifecycle events share the same trusted rider delivery pipeline.
      if ((record?.agent === 'rider_agent' || record?.agent === 'ride_lifecycle') && !record?.push_sent_at) {
        const { data: notification } = await supabase
          .from('notifications')
          .select('*')
          .eq('id', record.id)
          .single()

        if (notification) {
          const riderNotification: RiderNotificationRow = {
            target: 'rider',
            user_type: 'rider',
            user_id: notification.user_id as string,
            agent: notification.agent as 'rider_agent' | 'ride_lifecycle',
            category: notification.category as string,
            title: notification.title as string,
            body: notification.body as string,
            data: notification.data as Record<string, unknown>,
            priority: notification.priority as string,
            channel: notification.channel as string,
          }

          // Send FCM push and update push_sent_at
          const fcmTokens = await resolveRiderFcmTokens(supabase, {
            user_id: notification.user_id as string,
            data: notification.data as Record<string, unknown>,
          })

          let pushed = 0
          for (const token of fcmTokens) {
            // Import sendFcmNotification dynamically to avoid circular dependency
            const { sendFcmNotification } = await import('./notify_push.ts')
            await sendFcmNotification(token, {
              title: notification.title as string,
              body: notification.body as string,
              data: notification.data as Record<string, unknown>,
              priority: notification.priority as string,
            })
            pushed++
          }

          const liveActivityPushed = await deliverLiveActivityUpdate(supabase, riderNotification)

          // Mark push_sent_at
          await supabase
            .from('notifications')
            .update({ push_sent_at: new Date().toISOString() })
            .eq('id', record.id)

          return json({ ok: true, pushed, live_activity_pushed: liveActivityPushed })
        }
      }
      return ok()
    }

    // Manual trigger: POST with notification_id
    const manual = body as { notification_id?: string }
    if (manual?.notification_id) {
      // Auth check
      const expectedSecret = await webhookSecret(supabase)
      if (expectedSecret) {
        const incomingSecret = req.headers.get('x-webhook-secret') ?? ''
        const valid = await safeCompare(incomingSecret, expectedSecret)
        if (!valid) {
          return json({ error: 'Unauthorized' }, 401)
        }
      }

      const { data: notification } = await supabase
        .from('notifications')
        .select('*')
        .eq('id', manual.notification_id)
        .single()

      if (!notification || !['rider_agent', 'ride_lifecycle'].includes(notification.agent)) {
        return json({ error: 'Rider notification not found' }, 404)
      }

      const riderNotification: RiderNotificationRow = {
        target: 'rider',
        user_type: 'rider',
        user_id: notification.user_id as string,
        agent: notification.agent as 'rider_agent' | 'ride_lifecycle',
        category: notification.category as string,
        title: notification.title as string,
        body: notification.body as string,
        data: notification.data as Record<string, unknown>,
        priority: notification.priority as string,
        channel: notification.channel as string,
      }

      const fcmTokens = await resolveRiderFcmTokens(supabase, {
        user_id: notification.user_id as string,
        data: notification.data as Record<string, unknown>,
      })

      let pushed = 0
      for (const token of fcmTokens) {
        const { sendFcmNotification } = await import('./notify_push.ts')
        await sendFcmNotification(token, {
          title: notification.title as string,
          body: notification.body as string,
          data: notification.data as Record<string, unknown>,
          priority: notification.priority as string,
        })
        pushed++
      }

      const liveActivityPushed = await deliverLiveActivityUpdate(supabase, riderNotification)

      await supabase
        .from('notifications')
        .update({ push_sent_at: new Date().toISOString() })
        .eq('id', manual.notification_id)

      return json({ ok: true, pushed, live_activity_pushed: liveActivityPushed })
    }

    return json({ error: 'Invalid request' }, 400)
  } catch (e) {
    console.error('rider-agent error:', e)
    return json({ error: String(e) }, 500)
  }
})
