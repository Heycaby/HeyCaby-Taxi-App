#!/usr/bin/env python3
"""
Export a k6-ready driver manifest for Supabase driver location load tests.

The output contains synthetic driver IDs, user IDs, signed authenticated JWTs,
and seed coordinates. Treat it as a secret staging artifact and keep it under
build/load/.
"""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
from typing import Any, Dict, List

from supabase_scale_swarm import SupabaseRest, actors_from_rows


def main() -> int:
    parser = argparse.ArgumentParser(description="Export HeyCaby k6 driver load manifest")
    parser.add_argument("--drivers", type=int, default=5000)
    parser.add_argument("--country-code", default="NL")
    parser.add_argument("--center-lat", type=float, default=51.9244)
    parser.add_argument("--center-lng", type=float, default=4.4777)
    parser.add_argument("--driver-spread-km", type=float, default=18.0)
    parser.add_argument("--output", default="build/load/k6_scale_drivers.json")
    args = parser.parse_args()

    supabase_url = os.getenv("SUPABASE_URL", "")
    service_key = os.getenv("SUPABASE_SERVICE_KEY", "")
    anon_key = os.getenv("SUPABASE_ANON_KEY", "")
    jwt_secret = os.getenv("SUPABASE_JWT_SECRET", "")
    if not supabase_url or not service_key or not anon_key or not jwt_secret:
        raise SystemExit(
            "SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_KEY, and SUPABASE_JWT_SECRET are required"
        )

    rest = SupabaseRest(supabase_url, anon_key, service_key)
    rows = rest.fetch_drivers(args.country_code, args.drivers)
    actors = actors_from_rows(rows, jwt_secret, args.center_lat, args.center_lng, args.driver_spread_km)

    manifest: List[Dict[str, Any]] = [
        {
            "driver_id": actor.driver_id,
            "user_id": actor.user_id,
            "token": actor.token,
            "lat": actor.lat,
            "lng": actor.lng,
        }
        for actor in actors[: args.drivers]
    ]

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps({"drivers": manifest}, separators=(",", ":")) + "\n", encoding="utf-8")
    print(json.dumps({"output": str(output), "drivers": len(manifest)}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
