import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const ACTIVE_TRACKING_STATUSES = new Set([
  "assigned",
  "accepted",
  "driver_found",
  "driver_en_route",
  "driver_arrived",
  "arrived",
  "in_progress",
]);

const TERMINAL_STATUSES = new Set([
  "completed",
  "cancelled",
  "canceled",
  "rider_cancelled",
  "driver_cancelled",
  "declined",
  "expired",
  "no_driver",
]);

const baseHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Cache-Control": "no-store, max-age=0",
  "Content-Type": "application/json; charset=utf-8",
  "Referrer-Policy": "no-referrer",
  "X-Content-Type-Options": "nosniff",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: baseHeaders });
}

function firstName(full: string | null): string | null {
  if (!full) return null;
  const t = full.trim().split(/\s+/)[0];
  return t || null;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: baseHeaders });
  }
  if (req.method !== "GET" && req.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }

  let token: string | undefined;
  if (req.method === "POST") {
    try {
      const body = await req.json() as { token?: unknown };
      token = typeof body.token === "string" ? body.token.trim() : undefined;
    } catch {
      token = undefined;
    }
  } else {
    // Temporary compatibility for direct callers deployed before POST support.
    const url = new URL(req.url);
    token = url.searchParams.get("token")?.trim();
  }
  if (!token) {
    return json({ error: "not_found" }, 404);
  }
  if (!/^[a-f0-9]{24}$/i.test(token)) {
    return json({ error: "not_found" }, 404);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const supabase = createClient(supabaseUrl, serviceKey);

  const { data: row, error: e1 } = await supabase
    .from("ride_shares")
    .select("ride_request_id, is_active, expires_at, driver_snapshot")
    .eq("share_token", token)
    .maybeSingle();

  const expired = row?.expires_at &&
    new Date(row.expires_at as string).getTime() <= Date.now();
  if (e1 || !row || !row.is_active || expired) {
    return json({ error: "not_found" }, 404);
  }

  const rideId = row.ride_request_id as string;

  const { data: ride, error: e2 } = await supabase
    .from("ride_requests")
    .select(
      "id, status, pickup_address, destination_address, pickup_lat, pickup_lng, destination_lat, destination_lng, route_stops, route_revision, driver_id, scheduled_pickup_at",
    )
    .eq("id", rideId)
    .maybeSingle();

  if (e2 || !ride) {
    return json({ error: "not_found" }, 404);
  }

  const status = String(ride.status ?? "");
  const trackingActive = ACTIVE_TRACKING_STATUSES.has(status);
  const terminal = TERMINAL_STATUSES.has(status);

  let driver: Record<string, unknown> | null = null;
  const driverId = ride.driver_id as string | null;
  if (driverId && trackingActive) {
    const { data: d } = await supabase
      .from("drivers")
      .select("full_name, vehicle_model, vehicle_make, vehicle_plate")
      .eq("id", driverId)
      .maybeSingle();
    driver = d;

    const { data: ts } = await supabase
      .from("driver_trust_scores")
      .select("score")
      .eq("driver_id", driverId)
      .maybeSingle();

    if (driver && ts?.score != null) {
      driver = { ...driver, trust_score: ts.score };
    }
  }

  let lat: number | null = null;
  let lng: number | null = null;
  let heading: number | null = null;
  let locUpdated: string | null = null;
  if (driverId && trackingActive) {
    const { data: loc } = await supabase
      .from("driver_locations")
      .select("latitude, longitude, heading, updated_at")
      .eq("driver_id", driverId)
      .order("updated_at", { ascending: false })
      .limit(1)
      .maybeSingle();
    if (loc) {
      lat = loc.latitude as number;
      lng = loc.longitude as number;
      heading = loc.heading as number | null;
      locUpdated = loc.updated_at as string;
    }
  }

  const snap = row.driver_snapshot as Record<string, unknown> | null;
  const locationAgeSeconds = locUpdated
    ? Math.max(0, Math.floor((Date.now() - new Date(locUpdated).getTime()) / 1000))
    : null;

  const body = {
    ride_id: ride.id,
    status,
    tracking_active: trackingActive,
    terminal,
    expires_at: row.expires_at,
    server_time: new Date().toISOString(),
    pickup_address: ride.pickup_address,
    destination_address: ride.destination_address,
    pickup: ride.pickup_lat != null && ride.pickup_lng != null
      ? { lat: ride.pickup_lat, lng: ride.pickup_lng }
      : null,
    destination: ride.destination_lat != null && ride.destination_lng != null
      ? { lat: ride.destination_lat, lng: ride.destination_lng }
      : null,
    stops: ride.route_stops ?? [],
    route_revision: ride.route_revision ?? 0,
    scheduled_pickup_at: ride.scheduled_pickup_at,
    driver: driver
      ? {
        first_name: firstName(driver.full_name as string),
        vehicle: [driver.vehicle_make, driver.vehicle_model].filter(Boolean)
          .join(" ") || (driver.vehicle_model as string) || null,
        plate: driver.vehicle_plate,
        rating: driver.trust_score ?? null,
      }
      : snap
      ? {
        first_name: (snap.first_name ?? snap.name) as string | null,
        vehicle: snap.vehicle as string | null,
        plate: snap.plate as string | null,
        rating: snap.rating as number | null,
      }
      : null,
    driver_location: lat != null && lng != null
      ? {
        lat,
        lng,
        heading,
        updated_at: locUpdated,
        stale: locationAgeSeconds == null || locationAgeSeconds > 90,
        age_seconds: locationAgeSeconds,
      }
      : null,
  };

  return json(body);
});
