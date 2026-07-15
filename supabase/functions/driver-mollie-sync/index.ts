import {
  authenticatedUserId,
  corsOptions,
  decryptMollieToken,
  encryptMollieToken,
  fetchMollieOnboarding,
  json,
  refreshMollieOAuthToken,
  serviceClient,
} from "../_shared/ride_payment_service.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return corsOptions();
  if (req.method !== "POST") {
    return json({ ok: false, error: "method_not_allowed" }, 405);
  }
  const userId = await authenticatedUserId(req);
  if (userId instanceof Response) return userId;
  try {
    const admin = serviceClient();
    const { data: driver } = await admin.from("drivers").select("id")
      .eq("user_id", userId).maybeSingle();
    if (!driver?.id) return json({ ok: false, error: "not_a_driver" }, 403);
    const { data: connection } = await admin.from("driver_mollie_connections")
      .select("*").eq("driver_id", driver.id).maybeSingle();
    if (
      !connection?.access_token_ciphertext ||
      !connection.refresh_token_ciphertext
    ) {
      return json({ ok: false, error: "mollie_not_connected" }, 409);
    }

    let accessToken = await decryptMollieToken(
      connection.access_token_ciphertext,
    );
    let accessCiphertext = connection.access_token_ciphertext;
    let refreshCiphertext = connection.refresh_token_ciphertext;
    let expiresAt = connection.token_expires_at;
    let scopes = connection.scopes;
    if (!expiresAt || Date.parse(expiresAt) < Date.now() + 5 * 60 * 1000) {
      const refreshToken = await decryptMollieToken(
        connection.refresh_token_ciphertext,
      );
      const refreshed = await refreshMollieOAuthToken(refreshToken);
      accessToken = refreshed.access_token;
      [accessCiphertext, refreshCiphertext] = await Promise.all([
        encryptMollieToken(refreshed.access_token),
        encryptMollieToken(refreshed.refresh_token),
      ]);
      expiresAt = new Date(Date.now() + Number(refreshed.expires_in) * 1000)
        .toISOString();
      scopes = String(refreshed.scope ?? "").split(" ").filter(Boolean);
    }

    const onboarding = await fetchMollieOnboarding(accessToken);
    const verified = onboarding.status === "completed" &&
      onboarding.canReceivePayments === true &&
      onboarding.canReceiveSettlements === true;
    const now = new Date().toISOString();
    const { error } = await admin.from("driver_mollie_connections").update({
      status: verified ? "verified" : "onboarding",
      onboarding_status: onboarding.status ?? "unknown",
      can_receive_prepaid_rides: verified,
      access_token_ciphertext: accessCiphertext,
      refresh_token_ciphertext: refreshCiphertext,
      token_expires_at: expiresAt,
      scopes,
      verified_at: verified ? (connection.verified_at ?? now) : null,
      last_synced_at: now,
      last_error_code: null,
      updated_at: now,
    }).eq("driver_id", driver.id);
    if (error) throw error;
    return json({
      ok: true,
      status: verified ? "verified" : "onboarding",
      onboarding_status: onboarding.status ?? "unknown",
      can_receive_prepaid_rides: verified,
    });
  } catch (error) {
    console.error("driver-mollie-sync", error);
    return json({ ok: false, error: "mollie_sync_failed" }, 500);
  }
});
