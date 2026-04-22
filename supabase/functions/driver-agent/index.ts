// Driver Agent — transactional push via FCM HTTP v1 + rider pre-ride nudges.
// Triggered by DB webhooks (ride_requests, messages, ride_ratings) or
// POST { event: "preride_request", ride_request_id } with x-webhook-secret
// or Authorization: Bearer <driver JWT>.

import { createClient, serviceRoleKey, supabaseUrl, WEBHOOK_SECRET } from './config.ts'
import { buildAgentNotification } from './notify_rules.ts'
import type { AgentNotificationRow, ManualPreridePayload, WebhookPayload } from './notify_types.ts'
import { authorizeManualPreride, deliverNotification } from './notify_deliver.ts'
import { json, ok, safeCompare } from './util.ts'

Deno.serve(async (req) => {
  try {
    if (req.method === 'OPTIONS') return ok()

    if (!WEBHOOK_SECRET) {
      console.error('AGENT_WEBHOOK_SECRET env var not set — rejecting all requests')
      return json({ error: 'Misconfigured' }, 500)
    }

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

    const manual = body as ManualPreridePayload
    if (manual?.event === 'preride_request' && manual.ride_request_id) {
      const authorized = await authorizeManualPreride(req, manual.ride_request_id)
      if (!authorized) {
        console.warn('driver-agent: rejected preride_request (no secret / invalid JWT)')
        return json({ error: 'Unauthorized' }, 401)
      }
      const { data: ride } = await supabase
        .from('ride_requests')
        .select('id, rider_identity_id, rider_preride_request_sent_at')
        .eq('id', manual.ride_request_id)
        .maybeSingle()
      const rid = ride?.rider_identity_id as string | undefined
      const sent = ride?.rider_preride_request_sent_at
      if (!rid || !sent) return json({ error: 'ride_not_ready' }, 400)

      const notification: AgentNotificationRow = {
        target: 'rider',
        user_type: 'rider',
        user_id: rid,
        agent: 'driver_agent',
        category: 'preride_request',
        title: 'Bevestig je rit',
        body: 'Je chauffeur vraagt je rit te bevestigen vóór de rit.',
        data: { ride_request_id: manual.ride_request_id, screen: 'home' },
        priority: 'high',
        channel: 'both',
      }
      return await deliverNotification(supabase, notification, manual)
    }

    const incomingSecret = req.headers.get('x-webhook-secret') ?? ''
    const valid = await safeCompare(incomingSecret, WEBHOOK_SECRET)
    if (!valid) {
      console.warn('driver-agent: rejected request with invalid webhook secret')
      return json({ error: 'Unauthorized' }, 401)
    }

    const payload = body as WebhookPayload
    const { table, type, record } = payload
    if (!table || !type || !record) return json({ error: 'Missing table/type/record' }, 400)

    const notification = buildAgentNotification(payload)
    if (!notification) return ok()

    return await deliverNotification(supabase, notification, payload)
  } catch (e) {
    console.error('driver-agent error:', e)
    return json({ error: String(e) }, 500)
  }
})
