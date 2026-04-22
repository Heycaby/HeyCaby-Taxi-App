// apple-review-auth Edge Function
// Server-controlled App Store review login. Validates against app_config (not the app binary).
// Disable: UPDATE app_config SET value = 'false' WHERE key = 'apple_review_enabled';

import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY");

Deno.serve(async (req: Request) => {
  try {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type, Authorization, apikey",
      },
    });
  }

  if (req.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }

  let email: string;
  let otp: string;
  try {
    const body = await req.json();
    email = (body.email ?? "").trim().toLowerCase();
    otp = (body.otp ?? "").trim();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }

  if (!email || !otp) {
    return json({ error: "email_and_otp_required" }, 400);
  }

    if (!SUPABASE_URL || !SERVICE_ROLE_KEY || !ANON_KEY) {
      return json({ error: "missing_supabase_env" }, 500);
    }

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: rpcResult, error: rpcError } = await admin.rpc(
    "verify_review_otp",
    { p_email: email, p_otp: otp },
  );

  if (rpcError) {
    console.error("verify_review_otp error:", rpcError);
    return json({ error: "server_error" }, 500);
  }

  const result = rpcResult as { is_review?: boolean } | null;
  if (!result?.is_review) {
    return json({ error: "invalid_otp" }, 401);
  }

  const { data: cfgRows } = await admin
    .from("app_config")
    .select("value")
    .eq("key", "apple_review_email")
    .maybeSingle();
  const reviewEmail = (cfgRows?.value as string | undefined)?.trim()
    .toLowerCase() ?? "review@heycaby.nl";

    let userId: string | null = null;
    const { data: newUser, error: createError } = await admin.auth.admin
      .createUser({
        email: reviewEmail,
        email_confirm: true,
        user_metadata: { review_account: true },
      });
    if (!createError && newUser?.user?.id != null) {
      userId = newUser.user.id;
    }

    if (userId == null) {
      const { data: listed, error: listError } = await admin.auth.admin.listUsers();
      if (listError) {
        console.error("listUsers error:", listError);
        return json({ error: "failed_to_fetch_review_user" }, 500);
      }
      finalUser:
      for (const user of listed?.users ?? []) {
        if ((user.email ?? "").toLowerCase() == reviewEmail) {
          userId = user.id;
          break finalUser;
        }
      }
    }

    if (userId == null) {
      console.error("review user not found after create/list");
      return json({ error: "failed_to_create_review_user" }, 500);
    }

  const { error: setupErr } = await admin.rpc("setup_review_driver_profile", {
    p_user_id: userId,
  });
  if (setupErr) {
    console.error("setup_review_driver_profile error:", setupErr);
      // Do not block review login if profile bootstrap fails; app-side bootstrap can continue.
  }

  const { data: linkData, error: linkError } = await admin.auth.admin
    .generateLink({
      type: "magiclink",
      email: reviewEmail,
      options: { redirectTo: "heycaby://driver/auth/callback" },
    });

  if (linkError || !linkData?.properties) {
    console.error("generateLink error:", linkError);
    return json({ error: "failed_to_create_session" }, 500);
  }

    const { hashed_token: hashedToken, email_otp: emailOtp } = linkData.properties;
    const anonClient = createClient(SUPABASE_URL, ANON_KEY);

    let sessionData: { session: { access_token: string; refresh_token: string } } | null =
      null;
    let verifyError: unknown = null;

    if (hashedToken) {
      const verifyMagic = await anonClient.auth.verifyOtp({
        email: reviewEmail,
        token: hashedToken,
        type: "magiclink",
      });
      sessionData = verifyMagic.data as typeof sessionData;
      verifyError = verifyMagic.error;
    }

    // Fallback for runtimes/projects where generateLink exposes email_otp for type=email.
    if ((!sessionData?.session) && emailOtp) {
      const verifyEmailOtp = await anonClient.auth.verifyOtp({
        email: reviewEmail,
        token: emailOtp,
        type: "email",
      });
      sessionData = verifyEmailOtp.data as typeof sessionData;
      verifyError = verifyEmailOtp.error;
    }

    if (!sessionData?.session) {
      console.error("verifyOtp error:", verifyError);
      return json({ error: "failed_to_verify_session" }, 500);
    }

  console.log(
    `[apple-review-auth] OK user_id=${userId} email=${reviewEmail}`,
  );

  return json({
    access_token: sessionData.session.access_token,
    refresh_token: sessionData.session.refresh_token,
    token_type: "bearer",
    user_id: userId,
  });
  } catch (error) {
    console.error("apple-review-auth unhandled:", error);
    return json({ error: "unhandled_exception" }, 500);
  }
});

function json(obj: object, status = 200) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
    },
  });
}
