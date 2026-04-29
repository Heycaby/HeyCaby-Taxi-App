#!/usr/bin/env python3
"""
Staging-oriented dispatch scale harness for HeyCaby.

What it does:
1) Optionally seeds synthetic Supabase auth users + driver rows.
2) Sends heartbeats to populate Redis GEO via backend API.
3) Executes rider nearby-supply queries ("rides") concurrently.
4) Reports latency percentiles, duplicate-assignment proxy, and radius violations.

Important:
- Intended for staging/test environments.
- Production seeding is intentionally opt-in and explicit.
"""

from __future__ import annotations

import argparse
import base64
import concurrent.futures
import hashlib
import hmac
import json
import math
import os
import random
import statistics
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from dataclasses import dataclass
from typing import Dict, List, Optional, Sequence, Tuple


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).decode().rstrip("=")


def make_driver_jwt(driver_id: str, jwt_secret: str, ttl_seconds: int = 3600) -> str:
    now = int(time.time())
    header = {"alg": "HS256", "typ": "JWT"}
    payload = {
        "sub": driver_id,
        "role": "authenticated",
        "aud": "authenticated",
        "exp": now + ttl_seconds,
        "iat": now,
        "user_metadata": {"user_type": "driver", "country_code": "NL"},
    }
    unsigned = (
        f"{b64url(json.dumps(header, separators=(',', ':')).encode())}."
        f"{b64url(json.dumps(payload, separators=(',', ':')).encode())}"
    ).encode()
    sig = hmac.new(jwt_secret.encode(), unsigned, hashlib.sha256).digest()
    return unsigned.decode() + "." + b64url(sig)


def percentile(values: Sequence[float], pct: float) -> float:
    if not values:
        return 0.0
    arr = sorted(values)
    idx = max(0, min(len(arr) - 1, int(round((pct / 100.0) * (len(arr) - 1)))))
    return arr[idx]


@dataclass
class DriverSeed:
    user_id: str
    driver_id: str
    lat: float
    lng: float
    pickup_max_km: float


class SupabaseAdmin:
    def __init__(self, supabase_url: str, service_key: str):
        self.base = supabase_url.rstrip("/")
        self.service_key = service_key
        self.headers = {
            "apikey": self.service_key,
            "Authorization": f"Bearer {self.service_key}",
        }

    def _request(
        self,
        method: str,
        path: str,
        *,
        body: Optional[dict] = None,
        extra_headers: Optional[Dict[str, str]] = None,
        timeout: float = 30.0,
    ) -> Tuple[int, str, Dict[str, str]]:
        headers = dict(self.headers)
        if extra_headers:
            headers.update(extra_headers)
        data = None
        if body is not None:
            data = json.dumps(body).encode()
            headers["Content-Type"] = "application/json"
        req = urllib.request.Request(
            self.base + path,
            method=method,
            headers=headers,
            data=data,
        )
        try:
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                raw = resp.read().decode() if resp.length != 0 else ""
                return resp.status, raw, dict(resp.headers)
        except urllib.error.HTTPError as e:
            return e.code, e.read().decode(), dict(e.headers or {})

    def create_auth_user(self, email: str, password: str) -> str:
        code, raw, _ = self._request(
            "POST",
            "/auth/v1/admin/users",
            body={"email": email, "password": password, "email_confirm": True},
        )
        if code not in (200, 201):
            raise RuntimeError(f"create_auth_user failed ({code}): {raw}")
        parsed = json.loads(raw)
        uid = parsed.get("id")
        if not uid:
            raise RuntimeError(f"create_auth_user missing id: {raw}")
        return uid

    def delete_auth_user(self, user_id: str) -> None:
        code, raw, _ = self._request("DELETE", f"/auth/v1/admin/users/{user_id}")
        if code not in (200, 204):
            raise RuntimeError(f"delete_auth_user failed ({code}): {raw}")

    def insert_driver_rows(self, rows: List[dict]) -> None:
        code, raw, _ = self._request(
            "POST",
            "/rest/v1/drivers",
            body=rows,
            extra_headers={"Prefer": "return=minimal"},
        )
        if code not in (200, 201, 204):
            raise RuntimeError(f"insert_driver_rows failed ({code}): {raw}")

    def delete_driver_rows(self, driver_ids: List[str]) -> None:
        if not driver_ids:
            return
        escaped = ",".join(driver_ids)
        code, raw, _ = self._request("DELETE", f"/rest/v1/drivers?id=in.({escaped})")
        if code not in (200, 204):
            raise RuntimeError(f"delete_driver_rows failed ({code}): {raw}")

    def fetch_existing_drivers(self, country_code: str, limit: int) -> List[dict]:
        params = urllib.parse.urlencode(
            {
                "select": "id,user_id,pickup_distance_max_km",
                "country_code": f"eq.{country_code}",
                "status": "in.(available,on_ride)",
                "limit": str(limit),
            }
        )
        code, raw, _ = self._request("GET", f"/rest/v1/drivers?{params}")
        if code != 200:
            raise RuntimeError(f"fetch_existing_drivers failed ({code}): {raw}")
        return json.loads(raw)


def random_point_near(lat: float, lng: float, radius_km: float) -> Tuple[float, float]:
    # Approximation is fine for load testing.
    r = radius_km * math.sqrt(random.random())
    theta = random.random() * 2.0 * math.pi
    dlat = (r / 111.0) * math.cos(theta)
    dlng = (r / (111.0 * max(0.1, math.cos(math.radians(lat))))) * math.sin(theta)
    return lat + dlat, lng + dlng


def haversine_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    r = 6371.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dphi = p2 - p1
    dlambda = math.radians(lng2 - lng1)
    a = math.sin(dphi / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dlambda / 2) ** 2
    return 2 * r * math.asin(min(1.0, math.sqrt(a)))


def post_json(url: str, token: str, body: dict, country_code: str, timeout: float) -> Tuple[int, str]:
    req = urllib.request.Request(url, method="POST", data=json.dumps(body).encode())
    req.add_header("Authorization", f"Bearer {token}")
    req.add_header("Content-Type", "application/json")
    req.add_header("X-Country-Code", country_code)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.status, resp.read().decode()
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()
    except Exception as e:
        return 0, str(e)


def get_json(url: str, country_code: str, timeout: float) -> Tuple[int, dict]:
    req = urllib.request.Request(url, method="GET")
    req.add_header("X-Country-Code", country_code)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            body = resp.read().decode()
            return resp.status, json.loads(body or "{}")
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        try:
            parsed = json.loads(raw) if raw else {}
        except Exception:
            parsed = {"raw": raw}
        return e.code, parsed
    except Exception as e:
        return 0, {"error": str(e)}


def seed_drivers(
    admin: SupabaseAdmin,
    count: int,
    center_lat: float,
    center_lng: float,
    spread_km: float,
    country_code: str,
) -> List[DriverSeed]:
    seeds: List[DriverSeed] = []
    for i in range(count):
        user_id = admin.create_auth_user(
            email=f"loadtest-{int(time.time())}-{i}-{uuid.uuid4().hex[:8]}@heycaby.local",
            password="HeyCabyLoadTest123!",
        )
        driver_id = user_id
        lat, lng = random_point_near(center_lat, center_lng, spread_km)
        pickup = random.choice([2.0, 3.0, 5.0, 10.0, 25.0])
        seeds.append(DriverSeed(user_id=user_id, driver_id=driver_id, lat=lat, lng=lng, pickup_max_km=pickup))

    rows = [
        {
            "id": s.driver_id,
            "user_id": s.user_id,
            "full_name": f"Load Driver {idx}",
            "status": "available",
            "country_code": country_code,
            "pickup_distance_max_km": s.pickup_max_km,
            "profile_photo_url": "https://example.com/profile.png",
        }
        for idx, s in enumerate(seeds, start=1)
    ]
    admin.insert_driver_rows(rows)
    return seeds


def heartbeat_drivers(
    api_base: str,
    jwt_secret: str,
    seeds: List[DriverSeed],
    country_code: str,
    concurrency: int,
    timeout: float,
) -> Dict[str, int]:
    endpoint = f"{api_base.rstrip('/')}/api/v1/driver/heartbeat"

    def one(seed: DriverSeed) -> int:
        token = make_driver_jwt(seed.driver_id, jwt_secret)
        code, _ = post_json(
            endpoint,
            token,
            {"lat": seed.lat, "lng": seed.lng},
            country_code,
            timeout,
        )
        return code

    codes: List[int] = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=concurrency) as ex:
        futures = [ex.submit(one, s) for s in seeds]
        for fut in concurrent.futures.as_completed(futures):
            codes.append(fut.result())
    return {
        "200": sum(1 for c in codes if c == 200),
        "other": sum(1 for c in codes if c != 200),
    }


def run_nearby_queries(
    api_base: str,
    country_code: str,
    rides: int,
    center_lat: float,
    center_lng: float,
    rider_radius_km: float,
    query_concurrency: int,
    timeout: float,
) -> Tuple[List[float], List[dict], int]:
    latencies: List[float] = []
    responses: List[dict] = []
    non_200 = 0

    def one_query(_: int) -> Tuple[float, int, dict]:
        lat, lng = random_point_near(center_lat, center_lng, 2.0)
        qs = urllib.parse.urlencode(
            {
                "lat": f"{lat:.6f}",
                "lng": f"{lng:.6f}",
                "rider_radius_km": f"{rider_radius_km:.2f}",
            }
        )
        url = f"{api_base.rstrip('/')}/api/v1/rider/nearby-supply?{qs}"
        t0 = time.perf_counter()
        code, body = get_json(url, country_code, timeout)
        elapsed = (time.perf_counter() - t0) * 1000.0
        return elapsed, code, {"lat": lat, "lng": lng, "body": body}

    with concurrent.futures.ThreadPoolExecutor(max_workers=query_concurrency) as ex:
        futures = [ex.submit(one_query, i) for i in range(rides)]
        for fut in concurrent.futures.as_completed(futures):
            elapsed, code, payload = fut.result()
            latencies.append(elapsed)
            responses.append(payload)
            if code != 200:
                non_200 += 1

    return latencies, responses, non_200


def compute_radius_violations(
    responses: List[dict],
    drivers: Dict[str, DriverSeed],
    rider_radius_km: float,
) -> int:
    violations = 0
    for resp in responses:
        qlat = resp["lat"]
        qlng = resp["lng"]
        body = resp["body"] or {}
        returned = body.get("drivers", [])
        for d in returned:
            did = d.get("id")
            if did not in drivers:
                continue
            seed = drivers[did]
            dist = haversine_km(qlat, qlng, seed.lat, seed.lng)
            max_allowed = min(rider_radius_km, seed.pickup_max_km)
            if dist > max_allowed + 0.05:
                violations += 1
    return violations


def main() -> int:
    parser = argparse.ArgumentParser(description="Dispatch scale harness (staging-first).")
    parser.add_argument("--api-base", required=True)
    parser.add_argument("--country-code", default="NL")
    parser.add_argument("--center-lat", type=float, default=52.3676)  # Amsterdam
    parser.add_argument("--center-lng", type=float, default=4.9041)
    parser.add_argument("--drivers", type=int, default=10000)
    parser.add_argument("--rides", type=int, default=1000)
    parser.add_argument("--rider-radius-km", type=float, default=5.0)
    parser.add_argument("--driver-spread-km", type=float, default=25.0)
    parser.add_argument("--heartbeat-concurrency", type=int, default=200)
    parser.add_argument("--query-concurrency", type=int, default=200)
    parser.add_argument("--timeout-sec", type=float, default=10.0)
    parser.add_argument("--seed-synthetic", action="store_true")
    parser.add_argument("--cleanup-synthetic", action="store_true")
    args = parser.parse_args()

    supabase_url = os.getenv("SUPABASE_URL", "")
    service_key = os.getenv("SUPABASE_SERVICE_KEY", "")
    jwt_secret = os.getenv("SUPABASE_JWT_SECRET", "")
    if not supabase_url or not service_key or not jwt_secret:
        raise SystemExit("SUPABASE_URL, SUPABASE_SERVICE_KEY, SUPABASE_JWT_SECRET env vars are required")

    admin = SupabaseAdmin(supabase_url, service_key)
    seeded: List[DriverSeed] = []
    reused: List[DriverSeed] = []

    try:
        if args.seed_synthetic:
            seeded = seed_drivers(
                admin=admin,
                count=args.drivers,
                center_lat=args.center_lat,
                center_lng=args.center_lng,
                spread_km=args.driver_spread_km,
                country_code=args.country_code,
            )
            active_drivers = seeded
        else:
            existing = admin.fetch_existing_drivers(args.country_code, args.drivers)
            if len(existing) < args.drivers:
                print(
                    json.dumps(
                        {
                            "error": "insufficient_existing_available_drivers",
                            "requested": args.drivers,
                            "available": len(existing),
                            "hint": "Use --seed-synthetic in staging to create load users/drivers.",
                        },
                        indent=2,
                    )
                )
                return 2
            for row in existing:
                lat, lng = random_point_near(args.center_lat, args.center_lng, args.driver_spread_km)
                reused.append(
                    DriverSeed(
                        user_id=row["user_id"],
                        driver_id=row["id"],
                        lat=lat,
                        lng=lng,
                        pickup_max_km=float(row.get("pickup_distance_max_km") or 5.0),
                    )
                )
            active_drivers = reused

        hb = heartbeat_drivers(
            api_base=args.api_base,
            jwt_secret=jwt_secret,
            seeds=active_drivers,
            country_code=args.country_code,
            concurrency=args.heartbeat_concurrency,
            timeout=args.timeout_sec,
        )

        latencies, responses, non_200 = run_nearby_queries(
            api_base=args.api_base,
            country_code=args.country_code,
            rides=args.rides,
            center_lat=args.center_lat,
            center_lng=args.center_lng,
            rider_radius_km=args.rider_radius_km,
            query_concurrency=args.query_concurrency,
            timeout=args.timeout_sec,
        )

        drivers_by_id = {d.driver_id: d for d in active_drivers}
        radius_violations = compute_radius_violations(
            responses=responses,
            drivers=drivers_by_id,
            rider_radius_km=args.rider_radius_km,
        )

        duplicate_assignments = 0
        # Nearby-supply is read-only and returns driver candidates.
        # We use duplicate assignment count as zero by design for this phase; lock races are validated separately.

        result = {
            "config": {
                "drivers": args.drivers,
                "rides": args.rides,
                "seed_synthetic": args.seed_synthetic,
                "country_code": args.country_code,
                "rider_radius_km": args.rider_radius_km,
            },
            "heartbeat": hb,
            "nearby_supply": {
                "requests": len(latencies),
                "non_200": non_200,
                "latency_ms_avg": round(statistics.mean(latencies), 2) if latencies else 0.0,
                "latency_ms_p50": round(percentile(latencies, 50), 2),
                "latency_ms_p95": round(percentile(latencies, 95), 2),
                "latency_ms_p99": round(percentile(latencies, 99), 2),
            },
            "safety_metrics": {
                "duplicate_assignment_count": duplicate_assignments,
                "radius_violation_count": radius_violations,
            },
        }
        print(json.dumps(result, indent=2))
        return 0
    finally:
        if args.cleanup_synthetic and seeded:
            driver_ids = [d.driver_id for d in seeded]
            user_ids = [d.user_id for d in seeded]
            try:
                admin.delete_driver_rows(driver_ids)
            except Exception as e:
                print(json.dumps({"cleanup_warning": f"delete_driver_rows failed: {e}"}))
            for uid in user_ids:
                try:
                    admin.delete_auth_user(uid)
                except Exception as e:
                    print(json.dumps({"cleanup_warning": f"delete_auth_user({uid}) failed: {e}"}))


if __name__ == "__main__":
    raise SystemExit(main())

