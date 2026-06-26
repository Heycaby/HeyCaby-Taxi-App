// Driver Agent — transactional push via FCM HTTP v1 + rider pre-ride nudges.
// Triggered by DB webhooks (ride_requests, messages, ride_ratings) or
// POST { event: "preride_request", ride_request_id } with x-webhook-secret
// or Authorization: Bearer <driver JWT>.

import { createClient, serviceRoleKey, supabaseUrl, WEBHOOK_SECRET } from './config.ts'
import { buildAgentNotification } from './notify_rules.ts'
import type {
  AgentNotificationRow,
  ManualDriverPingPayload,
  ManualPreridePayload,
  WebhookPayload,
} from './notify_types.ts'
import { authorizeManualPreride, deliverNotification } from './notify_deliver.ts'
import {
  appendPingAudit,
  buildPingCopy,
  normalizePingKind,
  pingAuditEvent,
  pingNotificationCategory,
  recentPingCooldown,
  hasAutomaticPing,
} from './ping_helpers.ts'
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

    const manual = body as ManualPreridePayload | ManualDriverPingPayload

    if (manual?.event === 'driver_ping' && manual.ride_request_id) {
      const ping = manual as ManualDriverPingPayload
      const kind = normalizePingKind(ping.kind)
      if (!kind) return json({ error: 'invalid_ping_kind' }, 400)

      const authorized = await authorizeManualPreride(req, ping.ride_request_id)
      if (!authorized) {
        console.warn('driver-agent: rejected driver_ping (no secret / invalid JWT)')
        return json({ error: 'Unauthorized' }, 401)
      }

      const auditEvent = pingAuditEvent(kind)
      const isAutomatic = ping.automatic === true

      if (isAutomatic) {
        if (await hasAutomaticPing(supabase, ping.ride_request_id, auditEvent)) {
          return json({ ok: true, skipped: true, reason: 'automatic_dedupe' })
        }
      } else if (await recentPingCooldown(supabase, ping.ride_request_id, auditEvent)) {
        return json({ error: 'ping_cooldown', retry_after_seconds: 30 }, 429)
      }

      const { data: ride } = await supabase
        .from('ride_requests')
        .select('id, rider_identity_id, driver_id, status')
        .eq('id', ping.ride_request_id)
        .maybeSingle()
      const rid = ride?.rider_identity_id as string | undefined
      const driverFk = ride?.driver_id as string | undefined
      if (!rid) return json({ error: 'ride_not_found' }, 400)

      let driverRow: Record<string, unknown> | null = null
      if (driverFk) {
        const { data: drv } = await supabase
          .from('drivers')
          .select(
            'vehicle_plate, vehicle_make, vehicle_model, rdw_merk, rdw_handelsbenaming, user_id',
          )
          .eq('id', driverFk)
          .maybeSingle()
        driverRow = (drv as Record<string, unknown>) ?? null
      }

      const copy = buildPingCopy(kind, driverRow, ping.eta_minutes ?? null)
      const category = pingNotificationCategory(kind)
      const actorUserId = (driverRow?.user_id as string | undefined) ?? null

      await appendPingAudit(supabase, ping.ride_request_id, auditEvent, actorUserId, {
        ping_kind: kind === 'nearby' ? 'on_my_way' : kind,
        vehicle_plate: driverRow?.vehicle_plate ?? null,
        eta_minutes: ping.eta_minutes ?? null,
        delivery_state: 'sent',
        automatic: isAutomatic,
        source: isAutomatic ? 'automatic' : 'manual',
      })

      const notification: AgentNotificationRow = {
        target: 'rider',
        user_type: 'rider',
        user_id: rid,
        agent: 'driver_agent',
        category,
        title: copy.title,
        body: copy.body,
        data: {
          ride_request_id: ping.ride_request_id,
          screen: 'active',
          ping_kind: kind === 'nearby' ? 'on_my_way' : kind,
          audit_event: auditEvent,
          vehicle_label: driverRow
            ? `${driverRow.rdw_merk ?? driverRow.vehicle_make ?? ''} ${driverRow.rdw_handelsbenaming ?? driverRow.vehicle_model ?? ''}`.trim()
            : '',
          vehicle_plate: driverRow?.vehicle_plate ?? '',
          android_channel_id: copy.channelId,
          notification_type: 'driver_ping',
        },
        priority: copy.priority,
        channel: 'both',
      }
      return await deliverNotification(supabase, notification, ping)
    }

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
