import type { SupabaseClient } from "jsr:@supabase/supabase-js";

/** Resolve rider FCM tokens: identity id first, then session/push fallback. */
export async function resolveRiderFcmTokens(
  supabase: SupabaseClient,
  notification: {
    user_id: string;
    data?: Record<string, unknown> | null;
  },
): Promise<string[]> {
  const tokens = new Set<string>();
  const identityId = notification.user_id?.trim();
  if (!identityId) return [];

  const { data: byIdentity } = await supabase
    .from("push_devices")
    .select("fcm_token")
    .eq("rider_identity_id", identityId)
    .eq("app_role", "rider");

  for (const row of byIdentity ?? []) {
    const token = row?.fcm_token as string | null;
    if (token && token.length >= 10) tokens.add(token);
  }
  if (tokens.size > 0) return [...tokens];

  const rideId = notification.data?.ride_request_id as string | undefined;
  const riderToken = notification.data?.rider_token as string | undefined;
  let sessionUserId: string | null = null;

  if (riderToken?.trim()) {
    const { data: session } = await supabase
      .from("rider_sessions")
      .select("user_id")
      .eq("session_token", riderToken.trim())
      .maybeSingle();
    sessionUserId = (session?.user_id as string | null) ?? null;
  }

  if (!sessionUserId && rideId) {
    const { data: ride } = await supabase
      .from("ride_requests")
      .select("rider_token")
      .eq("id", rideId)
      .maybeSingle();
    const tokenFromRide = (ride?.rider_token as string | null)?.trim();
    if (tokenFromRide) {
      const { data: session } = await supabase
        .from("rider_sessions")
        .select("user_id")
        .eq("session_token", tokenFromRide)
        .maybeSingle();
      sessionUserId = (session?.user_id as string | null) ?? null;
    }
  }

  if (!sessionUserId) return [];

  const { data: byAuth } = await supabase
    .from("push_devices")
    .select("fcm_token")
    .eq("auth_user_id", sessionUserId)
    .eq("app_role", "rider");

  for (const row of byAuth ?? []) {
    const token = row?.fcm_token as string | null;
    if (token && token.length >= 10) tokens.add(token);
  }

  return [...tokens];
}
