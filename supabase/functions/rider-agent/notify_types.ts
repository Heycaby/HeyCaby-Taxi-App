export interface RiderNotificationRow {
  target: "rider";
  user_type: "rider";
  user_id: string;
  agent: "rider_agent";
  category: string;
  title: string;
  body: string;
  data: Record<string, unknown>;
  priority: string;
  channel: string;
}
