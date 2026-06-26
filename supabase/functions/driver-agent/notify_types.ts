export interface WebhookPayload {
  type: 'INSERT' | 'UPDATE' | 'DELETE'
  table: string
  record: Record<string, unknown>
  old_record?: Record<string, unknown> | null
}

export interface ManualPreridePayload {
  event: 'preride_request'
  ride_request_id: string
}

export interface ManualDriverPingPayload {
  event: 'driver_ping'
  ride_request_id: string
  kind:
    | 'on_my_way'
    | 'outside'
    | 'nearby'
    | 'arrived'
    | 'running_late'
    | 'traffic_delay'
    | 'cant_find_rider'
    | 'thanks'
  eta_minutes?: number
  /** System-initiated ping (accept / GPS). One per ride+kind. */
  automatic?: boolean
}

export type AgentNotificationRow = {
  target: 'driver' | 'rider'
  user_type: 'driver' | 'rider'
  user_id: string
  agent: 'driver_agent'
  category: string
  title: string
  body: string | null
  data: Record<string, unknown> | null
  priority: 'critical' | 'high' | 'medium' | 'low' | 'silent'
  channel: 'push' | 'in_app' | 'both' | 'silent'
}
