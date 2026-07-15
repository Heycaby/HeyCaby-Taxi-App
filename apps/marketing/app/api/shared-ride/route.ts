import { NextRequest, NextResponse } from "next/server";

import { SHARED_RIDE_TOKEN_PATTERN } from "../../../lib/shared-ride";

const PRODUCTION_SHARED_RIDE_ENDPOINT =
  "https://fvrprxguoternoxnyhoj.supabase.co/functions/v1/get-shared-ride";

const responseHeaders = {
  "Cache-Control": "no-store, max-age=0",
  "Referrer-Policy": "no-referrer",
  "X-Content-Type-Options": "nosniff",
};

export const dynamic = "force-dynamic";

async function serveProjection(request: NextRequest, token: string) {
  const startedAt = Date.now();
  const correlationId = crypto.randomUUID();
  const requestId = request.headers.get("x-vercel-id") ?? correlationId;

  if (!SHARED_RIDE_TOKEN_PATTERN.test(token)) {
    console.info(JSON.stringify({
      level: "info",
      message: "shared_ride_not_found",
      route: "/api/shared-ride",
      requestId,
      correlationId,
      reason: "invalid_token_format",
      durationMs: Date.now() - startedAt,
    }));
    return NextResponse.json(
      { error: "not_found", correlation_id: correlationId },
      { status: 404, headers: responseHeaders },
    );
  }

  try {
    const upstream = await fetch(
      PRODUCTION_SHARED_RIDE_ENDPOINT,
      {
        method: "POST",
        cache: "no-store",
        headers: {
          Accept: "application/json",
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ token }),
        signal: AbortSignal.timeout(8000),
      },
    );

    if (upstream.status === 404) {
      console.info(JSON.stringify({
        level: "info",
        message: "shared_ride_not_found",
        route: "/api/shared-ride",
        requestId,
        correlationId,
        reason: "unknown_or_expired",
        durationMs: Date.now() - startedAt,
      }));
      return NextResponse.json(
        { error: "not_found", correlation_id: correlationId },
        { status: 404, headers: responseHeaders },
      );
    }

    if (!upstream.ok) {
      console.error(JSON.stringify({
        level: "error",
        message: "shared_ride_upstream_failed",
        route: "/api/shared-ride",
        requestId,
        correlationId,
        upstreamStatus: upstream.status,
        durationMs: Date.now() - startedAt,
      }));
      return NextResponse.json(
        { error: "temporarily_unavailable", correlation_id: correlationId },
        { status: 502, headers: responseHeaders },
      );
    }

    const projection = await upstream.json();
    console.info(JSON.stringify({
      level: "info",
      message: "shared_ride_projection_served",
      route: "/api/shared-ride",
      requestId,
      correlationId,
      rideId: projection?.ride_id ?? null,
      status: projection?.status ?? null,
      trackingActive: projection?.tracking_active ?? false,
      durationMs: Date.now() - startedAt,
    }));
    return NextResponse.json(projection, {
      status: 200,
      headers: { ...responseHeaders, "X-Correlation-ID": correlationId },
    });
  } catch (error) {
    console.error(JSON.stringify({
      level: "error",
      message: "shared_ride_upstream_exception",
      route: "/api/shared-ride",
      requestId,
      correlationId,
      error: error instanceof Error ? error.message : "unknown",
      durationMs: Date.now() - startedAt,
    }));
    return NextResponse.json(
      { error: "temporarily_unavailable", correlation_id: correlationId },
      { status: 502, headers: responseHeaders },
    );
  }
}

export async function POST(request: NextRequest) {
  let token = "";
  try {
    const body = (await request.json()) as { token?: unknown };
    token = typeof body.token === "string" ? body.token.trim() : "";
  } catch {
    // Invalid JSON is deliberately indistinguishable from an unknown token.
  }
  return serveProjection(request, token);
}

// Temporary compatibility for a viewer bundle loaded before the POST rollout.
// New clients never put the capability token in a query string.
export async function GET(request: NextRequest) {
  const token = request.nextUrl.searchParams.get("token")?.trim() ?? "";
  return serveProjection(request, token);
}
