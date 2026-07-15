import type { SupabaseClient } from "jsr:@supabase/supabase-js";

import { sendFcmNotification } from "./notify_push.ts";

export type RiderPushBatchResult = {
  deviceCount: number;
  acceptedCount: number;
  failedCount: number;
  invalidTokenCount: number;
  errorCodes: string[];
};

export async function sendRiderPushBatch(
  supabase: SupabaseClient,
  tokens: string[],
  notification: {
    title: string;
    body: string | null;
    data?: Record<string, unknown>;
    priority?: string;
  },
): Promise<RiderPushBatchResult> {
  let acceptedCount = 0;
  let failedCount = 0;
  let invalidTokenCount = 0;
  const errorCodes = new Set<string>();

  for (const token of tokens) {
    const result = await sendFcmNotification(token, notification);
    if (result.ok) {
      acceptedCount += 1;
      continue;
    }

    failedCount += 1;
    if (result.errorCode) errorCodes.add(result.errorCode);
    if (result.permanentFailure) {
      invalidTokenCount += 1;
      await supabase
        .from("push_devices")
        .delete()
        .eq("fcm_token", token)
        .eq("app_role", "rider");
    }
  }

  return {
    deviceCount: tokens.length,
    acceptedCount,
    failedCount,
    invalidTokenCount,
    errorCodes: [...errorCodes],
  };
}
