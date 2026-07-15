/**
 * Public GET redirect for TAF QR codes (no JWT).
 * iOS → App Store (env override, else iTunes lookup by bundle id).
 * Android → Play Store (env override, else default listing for com.heycaby.rider).
 * Other → marketing invite URL on HEYCABY_PUBLIC_WEB_ORIGIN (preserves ?rider= or /i/{code}).
 */
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, HEAD, OPTIONS",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const defaultWebOrigin = "https://heycaby.nl";
const defaultAndroidListing =
  "https://play.google.com/store/apps/details?id=com.heycaby.rider";
const defaultIosBundle = "nl.heycaby.rider";

function redirect(location: string, status = 302): Response {
  return new Response(null, {
    status,
    headers: { ...cors, Location: location },
  });
}

async function resolveIosStoreUrl(bundleId: string): Promise<string | null> {
  const url =
    `https://itunes.apple.com/lookup?bundleId=${encodeURIComponent(bundleId)}&country=nl`;
  try {
    const r = await fetch(url, { headers: { Accept: "application/json" } });
    if (!r.ok) return null;
    const j = (await r.json()) as {
      resultCount?: number;
      results?: Array<{ trackViewUrl?: string }>;
    };
    const u = j.results?.[0]?.trackViewUrl;
    return typeof u === "string" && u.length > 0 ? u : null;
  } catch {
    return null;
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: cors });
  }
  if (req.method !== "GET" && req.method !== "HEAD") {
    return new Response("Method Not Allowed", { status: 405, headers: cors });
  }

  const url = new URL(req.url);
  const c = (url.searchParams.get("c") ?? "").trim();
  const rider = (url.searchParams.get("rider") ?? "").trim();

  const webOrigin = (Deno.env.get("HEYCABY_PUBLIC_WEB_ORIGIN") ?? defaultWebOrigin)
    .replace(/\/+$/, "");
  const codeOk = /^[a-zA-Z0-9]{7}$/.test(c);
  const inviteSuffix = codeOk
    ? `/i/${encodeURIComponent(c)}`
    : rider.length > 0
    ? `/invite?rider=${encodeURIComponent(rider)}`
    : "/invite";

  const ua = req.headers.get("user-agent") ?? "";
  const isIOS = /iPhone|iPad|iPod/i.test(ua) ||
    (/Macintosh/i.test(ua) && /Mobile/i.test(ua));
  const isAndroid = /Android/i.test(ua);

  const iosOverride = (Deno.env.get("RIDER_IOS_APP_STORE_URL") ?? "").trim();
  const androidOverride = (Deno.env.get("RIDER_ANDROID_PLAY_STORE_URL") ?? "")
    .trim();
  const bundle = (Deno.env.get("RIDER_IOS_BUNDLE_ID") ?? defaultIosBundle).trim();

  if (isIOS) {
    if (iosOverride) return redirect(iosOverride);
    const fromLookup = await resolveIosStoreUrl(bundle);
    if (fromLookup) return redirect(fromLookup);
    return redirect(`${webOrigin}${inviteSuffix}`);
  }

  if (isAndroid) {
    const target = androidOverride || defaultAndroidListing;
    return redirect(target);
  }

  return redirect(`${webOrigin}${inviteSuffix}`);
});

