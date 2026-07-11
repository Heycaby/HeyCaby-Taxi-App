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
import { resolveRiderFcmTokens } from './resolve_fcm_tokens.ts'
import { json, ok, safeCompare } from './util.ts'

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
      const record = webhook.record
      // Only process rider_agent notifications that haven't been sent yet
      if (record?.agent === 'rider_agent' && !record?.push_sent_at) {
        const { data: notification } = await supabase
          .from('notifications')
          .select('*')
          .eq('id', record.id)
          .single()

        if (notification) {
          const riderNotification: RiderNotificationRow = {
            target: 'rider',
            user_type: notification.user_type as string,
            user_id: notification.user_id as string,
            agent: notification.agent as string,
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

          // Mark push_sent_at
          await supabase
            .from('notifications')
            .update({ push_sent_at: new Date().toISOString() })
            .eq('id', record.id)

          return json({ ok: true, pushed })
        }
      }
      return ok()
    }

    // Manual trigger: POST with notification_id
    const manual = body as { notification_id?: string }
    if (manual?.notification_id) {
      // Auth check
      if (WEBHOOK_SECRET) {
        const incomingSecret = req.headers.get('x-webhook-secret') ?? ''
        const valid = await safeCompare(incomingSecret, WEBHOOK_SECRET)
        if (!valid) {
          return json({ error: 'Unauthorized' }, 401)
        }
      }

      const { data: notification } = await supabase
        .from('notifications')
        .select('*')
        .eq('id', manual.notification_id)
        .single()

      if (!notification || notification.agent !== 'rider_agent') {
        return json({ error: 'Notification not found or not rider_agent' }, 404)
      }

      const riderNotification: RiderNotificationRow = {
        target: 'rider',
        user_type: notification.user_type as string,
        user_id: notification.user_id as string,
        agent: notification.agent as string,
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

      await supabase
        .from('notifications')
        .update({ push_sent_at: new Date().toISOString() })
        .eq('id', manual.notification_id)

      return json({ ok: true, pushed })
    }

    return json({ error: 'Invalid request' }, 400)
  } catch (e) {
    console.error('rider-agent error:', e)
    return json({ error: String(e) }, 500)
  }
})
