import type { AgentNotificationRow, WebhookPayload } from './notify_types.ts'

export function buildAgentNotification(payload: WebhookPayload): AgentNotificationRow | null {
  const { type, table, record, old_record } = payload

  if (table === 'ride_requests') {
    const driverId = record?.driver_id as string | undefined
    const status = record?.status as string | undefined
    const oldStatus = old_record?.status as string | undefined
    const isMarket = record?.is_market === true
    const isScheduled = record?.is_scheduled === true
    const rideRequestId = record?.id as string | undefined

    if (type === 'UPDATE' && rideRequestId) {
      const oldSent = old_record?.rider_preride_request_sent_at
      const newSent = record?.rider_preride_request_sent_at
      if (!oldSent && newSent) {
        const riderIdentityId = record?.rider_identity_id as string | undefined
        if (riderIdentityId) {
          return {
            target: 'rider',
            user_type: 'rider',
            user_id: riderIdentityId,
            agent: 'driver_agent',
            category: 'preride_request',
            title: 'Bevestig je rit',
            body: 'Je chauffeur vraagt je rit te bevestigen vóór de rit.',
            data: { ride_request_id: rideRequestId, screen: 'home' },
            priority: 'high',
            channel: 'both',
          }
        }
      }
    }

    if (type === 'INSERT') {
      if (driverId) {
        return {
          target: 'driver',
          user_type: 'driver',
          user_id: driverId,
          agent: 'driver_agent',
          category: 'incoming_ride',
          title: '🚨 New ride request — 15 sec to accept',
          body: null,
          data: { ride_request_id: rideRequestId, screen: 'incoming' },
          priority: 'critical',
          channel: 'both',
        }
      }
      if (isMarket || isScheduled) return null
      return null
    }

    if (type === 'UPDATE' && driverId) {
      if (status === 'cancelled' && oldStatus !== 'cancelled') {
        return {
          target: 'driver',
          user_type: 'driver',
          user_id: driverId,
          agent: 'driver_agent',
          category: 'ride_phase',
          title: '⚠️ Rider cancelled the ride',
          body: null,
          data: { ride_request_id: rideRequestId },
          priority: 'high',
          channel: 'both',
        }
      }
    }
    return null
  }

  if ((table === 'messages' || table === 'ride_messages') && type === 'INSERT') {
    const senderType = record?.sender_type as string | undefined
    if (senderType !== 'rider') return null
    const rideRequestId = record?.ride_request_id as string | undefined
    if (!rideRequestId) return null
    const content = (record?.content as string) || (record?.body as string) || ''
    const preview = content.length > 60 ? content.slice(0, 57) + '...' : content
    return {
      target: 'driver',
      user_type: 'driver',
      user_id: '',
      agent: 'driver_agent',
      category: 'chat',
      title: '💬 [Rider]: ' + preview,
      body: preview,
      data: { ride_request_id: rideRequestId },
      priority: 'medium',
      channel: 'both',
    }
  }

  if (table === 'ride_ratings' && type === 'UPDATE') {
    const riderRating = record?.rider_rating_of_driver
    if (riderRating == null) return null
    const rideRequestId = record?.ride_request_id as string | undefined
    if (!rideRequestId) return null
    return {
      target: 'driver',
      user_type: 'driver',
      user_id: '',
      agent: 'driver_agent',
      category: 'rating',
      title: '⭐ You received a new rating',
      body: null,
      data: { ride_request_id: rideRequestId },
      priority: 'low',
      channel: 'both',
    }
  }

  return null
}
