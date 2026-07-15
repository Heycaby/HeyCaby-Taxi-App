import type { SupabaseClient } from "jsr:@supabase/supabase-js";

import type { RiderNotificationRow } from "./notify_types.ts";
import { resolveRiderFcmTokens } from "./resolve_fcm_tokens.ts";
import { sendRiderPushBatch } from "./push_batch.ts";

export async function deliverNotification(
  supabase: SupabaseClient,
  notification: RiderNotificationRow,
): Promise<Response> {
  // Insert notification into database
  const { data: inserted, error: insertError } = await supabase
    .from("notifications")
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
    .select("id")
    .single();

  if (insertError || !inserted) {
    console.error("Failed to insert notification:", insertError);
    return new Response(JSON.stringify({ error: "insert_failed" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  const notificationId = inserted.id as string;

  const fcmTokens = await resolveRiderFcmTokens(supabase, notification);

  const push = await sendRiderPushBatch(supabase, fcmTokens, {
    title: notification.title,
    body: notification.body,
    data: notification.data,
    priority: notification.priority,
  });

  if (push.acceptedCount > 0) {
    await supabase
      .from("notifications")
      .update({ push_sent_at: new Date().toISOString() })
      .eq("id", notificationId);
  }

  return new Response(
    JSON.stringify({
      ok: true,
      notification_id: notificationId,
      push_device_count: push.deviceCount,
      push_accepted_count: push.acceptedCount,
      push_failed_count: push.failedCount,
      invalid_token_count: push.invalidTokenCount,
      push_error_codes: push.errorCodes,
    }),
    {
      status: 200,
      headers: { "Content-Type": "application/json" },
    },
  );
}
