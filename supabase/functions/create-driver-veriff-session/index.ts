import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createHmac } from "node:crypto";
import {
  authenticatedDriver,
  corsOptions,
  json,
  serviceClient,
} from "../_shared/auth.ts";

function requiredEnv(name: string): string {
  const value = (Deno.env.get(name) ?? "").trim();
  if (!value) throw new Error(`missing_${name.toLowerCase()}`);
  return value;
}

function signPayload(payload: string, secret: string): string {
  return createHmac("sha256", secret).update(payload).digest("hex");
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return corsOptions();
  if (req.method !== "POST") {
    return json({ ok: false, error: "method_not_allowed" }, 405);
  }

  const actor = await authenticatedDriver(req);
  if (actor instanceof Response) return actor;

  let apiKey: string;
  let sharedSecret: string;
  try {
    apiKey = requiredEnv("VERIFF_API_KEY");
    sharedSecret = requiredEnv("VERIFF_SHARED_SECRET");
  } catch (error) {
    console.error(
      "[create-driver-veriff-session] provider not configured",
      error,
    );
    return json({ ok: false, error: "verification_provider_unavailable" }, 503);
  }

  const baseUrl = (Deno.env.get("VERIFF_BASE_URL") ??
    "https://stationapi.veriff.com").replace(/\/$/, "");
  const appUrl = (Deno.env.get("APP_URL") ?? "https://heycaby.nl").replace(
    /\/$/,
    "",
  );
  const admin = serviceClient();

  const { data: driver, error: driverError } = await admin
    .from("drivers")
    .select(
      "id, full_name, veriff_session_id, veriff_session_url, veriff_status",
    )
    .eq("id", actor.driverId)
    .maybeSingle();
  if (driverError || !driver) {
    return json({ ok: false, error: "driver_not_found" }, 404);
  }

  if (
    driver.veriff_session_id &&
    driver.veriff_session_url &&
    ["created", "started", "submitted"].includes(driver.veriff_status ?? "")
  ) {
    return json({
      ok: true,
      sessionId: driver.veriff_session_id,
      url: driver.veriff_session_url,
      status: driver.veriff_status,
      reused: true,
      verification: {
        id: driver.veriff_session_id,
        url: driver.veriff_session_url,
      },
    });
  }

  const nameParts = (driver.full_name ?? "").trim().split(/\s+/).filter(
    Boolean,
  );
  const payload = JSON.stringify({
    verification: {
      callback: `${appUrl}/driver/veriff/callback`,
      person: {
        firstName: nameParts[0] ?? "Driver",
        lastName: nameParts.slice(1).join(" ") || "Unknown",
      },
      document: { type: "DRIVERS_LICENSE", country: "NL" },
      vendorData: actor.driverId,
      endUserId: actor.driverId,
      timestamp: new Date().toISOString(),
    },
  });

  let response: Response;
  try {
    response = await fetch(`${baseUrl}/v1/sessions`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-auth-client": apiKey,
        "x-hmac-signature": signPayload(payload, sharedSecret),
      },
      body: payload,
      signal: AbortSignal.timeout(15_000),
    });
  } catch (error) {
    console.error(
      "[create-driver-veriff-session] provider request failed",
      error,
    );
    return json({ ok: false, error: "verification_provider_unavailable" }, 502);
  }

  if (!response.ok) {
    console.error(
      `[create-driver-veriff-session] provider status=${response.status}`,
    );
    return json({ ok: false, error: "verification_provider_error" }, 502);
  }

  const provider = await response.json();
  const verification = provider?.verification;
  const sessionId = verification?.id;
  const sessionUrl = verification?.url;
  if (provider?.status !== "success" || !sessionId || !sessionUrl) {
    console.error("[create-driver-veriff-session] invalid provider response");
    return json({ ok: false, error: "verification_provider_error" }, 502);
  }

  const { error: saveError } = await admin.from("drivers").update({
    veriff_session_id: sessionId,
    veriff_session_url: sessionUrl,
    veriff_status: "created",
    veriff_attempt_id: null,
    veriff_decision: null,
    updated_at: new Date().toISOString(),
  }).eq("id", actor.driverId);
  if (saveError) {
    console.error(
      "[create-driver-veriff-session] persistence failed",
      saveError,
    );
    return json({ ok: false, error: "verification_session_save_failed" }, 500);
  }

  return json({
    ok: true,
    sessionId,
    url: sessionUrl,
    status: "created",
    verification: { id: sessionId, url: sessionUrl, status: "created" },
  });
});
