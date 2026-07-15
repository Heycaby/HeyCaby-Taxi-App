import {
  authenticatedUserId,
  corsOptions,
  json,
  parseJsonConfig,
  serviceClient,
  sha256Hex,
} from "../_shared/ride_payment_service.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return corsOptions();
  if (req.method !== "POST") {
    return json({ ok: false, error: "method_not_allowed" }, 405);
  }
  const userId = await authenticatedUserId(req);
  if (userId instanceof Response) return userId;
  try {
    const clientId = (Deno.env.get("MOLLIE_CONNECT_CLIENT_ID") ?? "").trim();
    const redirectUri = (Deno.env.get("MOLLIE_CONNECT_REDIRECT_URI") ?? "")
      .trim();
    if (!clientId || !redirectUri) {
      return json({ ok: false, error: "mollie_connect_not_configured" }, 503);
    }
    const admin = serviceClient();
    const [{ data: driver }, { data: flagRow }] = await Promise.all([
      admin.from("drivers").select("id").eq("user_id", userId).maybeSingle(),
      admin.from("app_config").select("value").eq("key", "feature_flags")
        .maybeSingle(),
    ]);
    if (!driver?.id) return json({ ok: false, error: "not_a_driver" }, 403);
    const flags = parseJsonConfig(flagRow?.value);
    if (flags.ride_prepaid_driver_connect_enabled !== true) {
      return json({ ok: false, error: "mollie_connect_disabled" }, 409);
    }

    const state = `${crypto.randomUUID()}${crypto.randomUUID()}`.replaceAll(
      "-",
      "",
    );
    const stateHash = await sha256Hex(state);
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString();
    const { error } = await admin.from("mollie_oauth_states").insert({
      state_hash: stateHash,
      driver_id: driver.id,
      redirect_uri: redirectUri,
      expires_at: expiresAt,
    });
    if (error) throw error;
    const authorize = new URL("https://my.mollie.com/oauth2/authorize");
    authorize.search = new URLSearchParams({
      client_id: clientId,
      state,
      scope:
        "organizations.read onboarding.read profiles.read payments.read payments.write refunds.read refunds.write",
      response_type: "code",
      approval_prompt: "auto",
      redirect_uri: redirectUri,
    }).toString();
    return json({
      ok: true,
      authorize_url: authorize.toString(),
      expires_at: expiresAt,
    });
  } catch (error) {
    console.error("driver-mollie-connect", error);
    return json({ ok: false, error: "connect_start_failed" }, 500);
  }
});
