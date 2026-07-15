import {
  encryptMollieToken,
  exchangeMollieOAuthCode,
  fetchMollieOrganization,
  json,
  serviceClient,
  sha256Hex,
} from "../_shared/ride_payment_service.ts";

Deno.serve(async (req: Request) => {
  if (req.method !== "GET") {
    return json({ ok: false, error: "method_not_allowed" }, 405);
  }
  const url = new URL(req.url);
  const code = url.searchParams.get("code")?.trim() ?? "";
  const state = url.searchParams.get("state")?.trim() ?? "";
  const appReturnUrl = (Deno.env.get("MOLLIE_CONNECT_APP_RETURN_URL") ??
    "heycaby-driver://mollie/connect").trim();
  const redirect = (status: string) =>
    Response.redirect(
      `${appReturnUrl}?status=${encodeURIComponent(status)}`,
      302,
    );
  if (!code || !state) return redirect("invalid_callback");

  try {
    const admin = serviceClient();
    const stateHash = await sha256Hex(state);
    const { data: oauthState } = await admin.from("mollie_oauth_states")
      .select("driver_id, redirect_uri, expires_at, consumed_at")
      .eq("state_hash", stateHash).maybeSingle();
    if (
      !oauthState || oauthState.consumed_at ||
      Date.parse(oauthState.expires_at) <= Date.now()
    ) {
      return redirect("invalid_state");
    }
    const consumedAt = new Date().toISOString();
    const { data: consumed, error: consumeError } = await admin
      .from("mollie_oauth_states")
      .update({ consumed_at: consumedAt })
      .eq("state_hash", stateHash)
      .is("consumed_at", null)
      .select("driver_id").maybeSingle();
    if (consumeError || !consumed) return redirect("state_already_used");

    const tokens = await exchangeMollieOAuthCode({
      code,
      redirectUri: oauthState.redirect_uri,
    });
    const organization = await fetchMollieOrganization(tokens.access_token);
    const [accessCiphertext, refreshCiphertext] = await Promise.all([
      encryptMollieToken(tokens.access_token),
      encryptMollieToken(tokens.refresh_token),
    ]);
    const tokenExpiresAt = new Date(
      Date.now() + Math.max(60, Number(tokens.expires_in ?? 3600)) * 1000,
    ).toISOString();
    const { error } = await admin.from("driver_mollie_connections").upsert({
      driver_id: oauthState.driver_id,
      organization_id: organization.id,
      status: "onboarding",
      onboarding_status: "needs_review",
      can_receive_prepaid_rides: false,
      access_token_ciphertext: accessCiphertext,
      refresh_token_ciphertext: refreshCiphertext,
      token_expires_at: tokenExpiresAt,
      scopes: String(tokens.scope ?? "").split(" ").filter(Boolean),
      connected_at: consumedAt,
      last_synced_at: consumedAt,
      last_error_code: null,
      updated_at: consumedAt,
    }, { onConflict: "driver_id" });
    if (error) throw error;
    return redirect("connected_pending_verification");
  } catch (error) {
    console.error("driver-mollie-oauth-callback", error);
    return redirect("connect_failed");
  }
});
