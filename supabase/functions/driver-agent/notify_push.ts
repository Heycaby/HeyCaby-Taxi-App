import type { SupabaseClient } from "jsr:@supabase/supabase-js";

import { type FcmSendResult, sendFcmV1ToToken } from "./fcm_v1.ts";
import { isApnsConfigured, sendApnsToToken } from "./apns.ts";

export type PushResult = {
  ok: boolean;
  permanentFailure: boolean;
  statusCode?: number;
  errorCode?: string;
  providerMessageId?: string;
  provider?: "apns" | "fcm";
  invalidApnsToken?: boolean;
  apnsEnvironment?: "sandbox" | "production";
};

export async function getDriverIdForRideRequest(
  supabase: SupabaseClient,
  rideRequestId: string,
): Promise<string | null> {
  const { data } = await supabase.from("ride_requests").select("driver_id").eq(
    "id",
    rideRequestId,
  ).single();
  return (data?.driver_id as string) ?? null;
}

/** Sends one notification via direct APNs (preferred for iOS) or FCM fallback. */
export async function sendPushNotification(
  device: {
    fcm_token: string | null;
    apns_token: string | null;
    apns_environment: string | null;
    platform: string;
    app_role: string;
  },
  notification: {
    title: string;
    body: string | null;
    data?: Record<string, unknown>;
    priority?: string;
    androidChannelId?: string;
  },
): Promise<PushResult> {
  const channelFromData = notification.data?.android_channel_id as
    | string
    | undefined;
  const androidChannelId = notification.androidChannelId ?? channelFromData;

  // Prefer direct APNs for iOS when available
  let invalidApnsToken = false;
  if (
    device.platform === "ios" && device.apns_token &&
    device.apns_token.length > 10 && isApnsConfigured()
  ) {
    const bundleId = device.app_role === "rider"
      ? "nl.heycaby.rider.app"
      : "nl.heycaby.driver.app";
    const preferredEnvironment: "sandbox" | "production" =
      device.apns_environment === "sandbox" ? "sandbox" : "production";
    let resolvedEnvironment: "sandbox" | "production" = preferredEnvironment;
    let apnsResult = await sendApnsToToken(device.apns_token, {
      title: notification.title,
      body: notification.body,
      data: notification.data,
      priority: notification.priority,
      bundleId,
      environment: preferredEnvironment,
    });
    if (
      !apnsResult.ok &&
      ["BadDeviceToken", "DeviceTokenNotForTopic"].includes(
        apnsResult.errorCode ?? "",
      )
    ) {
      resolvedEnvironment = preferredEnvironment === "sandbox"
        ? "production"
        : "sandbox";
      apnsResult = await sendApnsToToken(device.apns_token, {
        title: notification.title,
        body: notification.body,
        data: notification.data,
        priority: notification.priority,
        bundleId,
        environment: resolvedEnvironment,
      });
    }
    if (apnsResult.ok) {
      return {
        ...apnsResult,
        provider: "apns",
        apnsEnvironment: resolvedEnvironment,
      };
    }
    invalidApnsToken = apnsResult.permanentFailure;

    // Direct APNs provider errors must not discard or bypass a still-valid
    // Firebase registration for the same device. Fall back once to FCM.
    if (!device.fcm_token || device.fcm_token.length < 10) {
      return {
        ...apnsResult,
        provider: "apns",
        invalidApnsToken,
      };
    }
  }

  // Fallback to FCM
  const fcmToken = device.fcm_token;
  if (!fcmToken || fcmToken.length < 10) {
    return {
      ok: false,
      permanentFailure: true,
      errorCode: "invalid_local_token",
    };
  }
  const result = await sendFcmV1ToToken(fcmToken, {
    ...notification,
    androidChannelId,
  });
  return { ...result, provider: "fcm", invalidApnsToken };
}

/** Legacy alias — sends via FCM only. */
export async function sendFcmNotification(
  fcmToken: string | null,
  notification: {
    title: string;
    body: string | null;
    data?: Record<string, unknown>;
    priority?: string;
    androidChannelId?: string;
  },
): Promise<FcmSendResult> {
  if (!fcmToken || fcmToken.length < 10) {
    return {
      ok: false,
      permanentFailure: true,
      errorCode: "invalid_local_token",
    };
  }
  const channelFromData = notification.data?.android_channel_id as
    | string
    | undefined;
  return await sendFcmV1ToToken(fcmToken, {
    ...notification,
    androidChannelId: notification.androidChannelId ?? channelFromData,
  });
}

export async function recentPrerideNotification(
  supabase: SupabaseClient,
  rideRequestId: string,
): Promise<boolean> {
  const since = new Date(Date.now() - 120_000).toISOString();
  const { data, error } = await supabase
    .from("notifications")
    .select("id")
    .eq("category", "preride_request")
    .contains("data", { ride_request_id: rideRequestId })
    .gte("created_at", since)
    .limit(1);
  if (error) return false;
  return (data?.length ?? 0) > 0;
}
