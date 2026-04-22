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
