#!/usr/bin/env python3
"""
Supabase-native scale harness for HeyCaby driver-density testing.

Runs 5k-driver location pressure at separate 3s/5s/10s intervals while
layering rider nearby-supply and optional booking/matching load on top.

Intended for staging first. Production credentials are intentionally not
special-cased here; point this only at an environment you are prepared to load.
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
import subprocess
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from collections import Counter, defaultdict, deque
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Deque, Dict, Iterable, List, Optional, Sequence, Tuple


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).decode().rstrip("=")


def make_supabase_jwt(user_id: str, jwt_secret: str, ttl_seconds: int = 86400) -> str:
    now = int(time.time())
    header = {"alg": "HS256", "typ": "JWT"}
    payload = {
        "sub": user_id,
        "role": "authenticated",
        "aud": "authenticated",
        "exp": now + ttl_seconds,
        "iat": now,
        "app_metadata": {"provider": "loadtest", "providers": ["loadtest"]},
        "user_metadata": {"load_test": True},
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


def random_point_near(lat: float, lng: float, radius_km: float) -> Tuple[float, float]:
    r = radius_km * math.sqrt(random.random())
    theta = random.random() * 2.0 * math.pi
    dlat = (r / 111.0) * math.cos(theta)
    dlng = (r / (111.0 * max(0.1, math.cos(math.radians(lat))))) * math.sin(theta)
    return lat + dlat, lng + dlng


@dataclass(frozen=True)
class DriverActor:
    driver_id: str
    user_id: str
    token: str
    lat: float
    lng: float


class RollingMetrics:
    def __init__(self) -> None:
        self._lock = threading.Lock()
        self.counts: Counter[str] = Counter()
        self.latencies_ms: Dict[str, List[float]] = defaultdict(list)
        self.errors: Deque[str] = deque(maxlen=50)

    def record(self, name: str, ok: bool, elapsed_ms: float, detail: str = "") -> None:
        with self._lock:
            self.counts[f"{name}.total"] += 1
            self.counts[f"{name}.ok" if ok else f"{name}.error"] += 1
            self.latencies_ms[name].append(elapsed_ms)
            if not ok and detail:
                self.errors.append(f"{name}: {detail[:240]}")

    def snapshot(self) -> Dict[str, Any]:
        with self._lock:
            latency = {
                name: {
                    "count": len(values),
                    "avg_ms": round(statistics.mean(values), 2) if values else 0.0,
                    "p50_ms": round(percentile(values, 50), 2),
                    "p95_ms": round(percentile(values, 95), 2),
                    "p99_ms": round(percentile(values, 99), 2),
                }
                for name, values in self.latencies_ms.items()
            }
            return {
                "counts": dict(self.counts),
                "latency": latency,
                "recent_errors": list(self.errors),
            }


class SupabaseRest:
    def __init__(self, url: str, anon_key: str, service_key: Optional[str]) -> None:
        self.base = url.rstrip("/")
        self.anon_key = anon_key
        self.service_key = service_key

    def request(
        self,
        method: str,
        path: str,
        *,
        key: str,
        bearer: str,
        body: Optional[Any] = None,
        headers: Optional[Dict[str, str]] = None,
        timeout: float = 10.0,
    ) -> Tuple[int, str]:
        req_headers = {
            "apikey": key,
            "Authorization": f"Bearer {bearer}",
            "Content-Type": "application/json",
        }
        if headers:
            req_headers.update(headers)
        data = json.dumps(body).encode() if body is not None else None
        req = urllib.request.Request(
            self.base + path,
            method=method,
            data=data,
            headers=req_headers,
        )
        try:
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                return resp.status, resp.read().decode()
        except urllib.error.HTTPError as e:
            return e.code, e.read().decode()
        except Exception as e:
            return 0, str(e)

    def service_request(
        self,
        method: str,
        path: str,
        *,
        body: Optional[Any] = None,
        headers: Optional[Dict[str, str]] = None,
        timeout: float = 20.0,
    ) -> Tuple[int, str]:
        if not self.service_key:
            raise RuntimeError("SUPABASE_SERVICE_KEY is required for service operations")
        return self.request(
            method,
            path,
            key=self.service_key,
            bearer=self.service_key,
            body=body,
            headers=headers,
            timeout=timeout,
        )

    def fetch_drivers(self, country_code: str, limit: int) -> List[Dict[str, Any]]:
        query = urllib.parse.urlencode(
            {
                "select": "id,user_id",
                "country_code": f"eq.{country_code}",
                "status": "in.(available,on_ride,offline,on_break)",
                "user_id": "not.is.null",
                "limit": str(limit),
            }
        )
        code, raw = self.service_request("GET", f"/rest/v1/drivers?{query}")
        if code != 200:
            raise RuntimeError(f"fetch_drivers failed ({code}): {raw}")
        rows = json.loads(raw or "[]")
        if len(rows) < limit:
            raise RuntimeError(f"Only found {len(rows)} drivers; need {limit}. Seed staging or lower --drivers.")
        return rows[:limit]

    def create_auth_user(self, email: str, password: str) -> str:
        code, raw = self.service_request(
            "POST",
            "/auth/v1/admin/users",
            body={"email": email, "password": password, "email_confirm": True},
            timeout=30.0,
        )
        if code not in (200, 201):
            raise RuntimeError(f"create_auth_user failed ({code}): {raw}")
        uid = json.loads(raw).get("id")
        if not uid:
            raise RuntimeError(f"create_auth_user missing id: {raw}")
        return uid

    def insert_driver_rows(self, rows: List[Dict[str, Any]]) -> None:
        code, raw = self.service_request(
            "POST",
            "/rest/v1/drivers",
            body=rows,
            headers={"Prefer": "return=minimal"},
            timeout=60.0,
        )
        if code not in (200, 201, 204):
            raise RuntimeError(f"insert_driver_rows failed ({code}): {raw}")

    def seed_drivers(
        self,
        *,
        count: int,
        country_code: str,
        center_lat: float,
        center_lng: float,
        spread_km: float,
        batch_size: int,
    ) -> List[Dict[str, Any]]:
        rows: List[Dict[str, Any]] = []
        stamp = int(time.time())
        for idx in range(count):
            uid = self.create_auth_user(
                f"scale-{stamp}-{idx}-{uuid.uuid4().hex[:8]}@heycaby.local",
                "HeyCabyLoadTest123!",
            )
            lat, lng = random_point_near(center_lat, center_lng, spread_km)
            rows.append(
                {
                    "id": uid,
                    "user_id": uid,
                    "full_name": f"Scale Driver {idx}",
                    "status": "available",
                    "country_code": country_code,
                    "vehicle_category": random.choice(["standard", "comfort", "xl"]),
                    "pickup_distance_max_km": random.choice([3, 5, 10, 25]),
                    "profile_photo_url": "https://example.com/heycaby-scale-driver.png",
                    "_seed_lat": lat,
                    "_seed_lng": lng,
                }
            )
            if len(rows) % batch_size == 0:
                self._flush_driver_rows(rows[-batch_size:])
        remainder = len(rows) % batch_size
        if remainder:
            self._flush_driver_rows(rows[-remainder:])
        return rows

    def _flush_driver_rows(self, rows: List[Dict[str, Any]]) -> None:
        clean = [{k: v for k, v in row.items() if not k.startswith("_")} for row in rows]
        self.insert_driver_rows(clean)


def load_manifest(path: Path, jwt_secret: str, center_lat: float, center_lng: float, spread_km: float) -> List[DriverActor]:
    actors: List[DriverActor] = []
    for line in path.read_text().splitlines():
        if not line.strip():
            continue
        row = json.loads(line)
        lat = float(row.get("lat") or random_point_near(center_lat, center_lng, spread_km)[0])
        lng = float(row.get("lng") or random_point_near(center_lat, center_lng, spread_km)[1])
        user_id = row["user_id"]
        actors.append(
            DriverActor(
                driver_id=row["driver_id"],
                user_id=user_id,
                token=make_supabase_jwt(user_id, jwt_secret),
                lat=lat,
                lng=lng,
            )
        )
    return actors


def write_manifest(path: Path, actors: Iterable[DriverActor]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w") as f:
        for actor in actors:
            f.write(json.dumps({"driver_id": actor.driver_id, "user_id": actor.user_id, "lat": actor.lat, "lng": actor.lng}) + "\n")


def actors_from_rows(rows: List[Dict[str, Any]], jwt_secret: str, center_lat: float, center_lng: float, spread_km: float) -> List[DriverActor]:
    actors: List[DriverActor] = []
    for row in rows:
        lat = float(row.get("_seed_lat") or random_point_near(center_lat, center_lng, spread_km)[0])
        lng = float(row.get("_seed_lng") or random_point_near(center_lat, center_lng, spread_km)[1])
        actors.append(
            DriverActor(
                driver_id=row["id"],
                user_id=row["user_id"],
                token=make_supabase_jwt(row["user_id"], jwt_secret),
                lat=lat,
                lng=lng,
            )
        )
    return actors


def upsert_driver_location(rest: SupabaseRest, actor: DriverActor, country_code: str, timeout: float) -> Tuple[bool, str]:
    lat, lng = random_point_near(actor.lat, actor.lng, 0.15)
    body = {
        "user_id": actor.user_id,
        "driver_id": actor.driver_id,
        "latitude": round(lat, 7),
        "longitude": round(lng, 7),
        "heading": round(random.random() * 360.0, 1),
        "country_code": country_code,
        "updated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }
    qs = urllib.parse.urlencode({"on_conflict": "user_id"})
    code, raw = rest.request(
        "POST",
        f"/rest/v1/driver_locations?{qs}",
        key=rest.anon_key,
        bearer=actor.token,
        body=body,
        headers={"Prefer": "resolution=merge-duplicates,return=minimal"},
        timeout=timeout,
    )
    return code in (200, 201, 204), f"{code} {raw[:180]}"


def rider_nearby_supply(rest: SupabaseRest, center_lat: float, center_lng: float, timeout: float) -> Tuple[bool, str]:
    lat, lng = random_point_near(center_lat, center_lng, 3.0)
    body = {
        "p_lat": round(lat, 7),
        "p_lng": round(lng, 7),
        "p_radius_km": 12.0,
        "p_max_age_minutes": 3,
    }
    code, raw = rest.request(
        "POST",
        "/rest/v1/rpc/fn_rider_nearby_supply",
        key=rest.anon_key,
        bearer=rest.anon_key,
        body=body,
        timeout=timeout,
    )
    return code == 200, f"{code} {raw[:180]}"


def create_booking_and_seed(rest: SupabaseRest, center_lat: float, center_lng: float, timeout: float) -> Tuple[bool, str]:
    if not rest.service_key:
        return False, "service key unavailable"
    lat, lng = random_point_near(center_lat, center_lng, 4.0)
    rider_token = f"scale-{uuid.uuid4()}"
    ride = {
        "pickup_address": "Scale Test Pickup",
        "destination_address": "Scale Test Destination",
        "pickup_lat": lat,
        "pickup_lng": lng,
        "destination_lat": lat + 0.02,
        "destination_lng": lng + 0.02,
        "pickup_coords": f"SRID=4326;POINT({lng} {lat})",
        "status": "pending",
        "booking_mode": "instant",
        "rider_token": rider_token,
        "pickup_contact_name": "Scale Harness",
        "payment_methods": ["cash"],
    }
    code, raw = rest.service_request(
        "POST",
        "/rest/v1/ride_requests?select=id",
        body=ride,
        headers={"Prefer": "return=representation"},
        timeout=timeout,
    )
    if code not in (200, 201):
        return False, f"insert {code} {raw[:180]}"
    try:
        ride_id = json.loads(raw)[0]["id"]
    except Exception:
        return False, f"insert parse {raw[:180]}"
    code, raw = rest.service_request(
        "POST",
        "/rest/v1/rpc/fn_seed_ride_matching_batch",
        body={"p_ride_request_id": ride_id, "p_batch_size": 4, "p_window_seconds": 30},
        timeout=timeout,
    )
    return code == 200, f"seed {code} {raw[:180]}"


def db_metric_snapshot(database_url: str) -> Dict[str, Any]:
    sql = r"""
select json_build_object(
  'sampled_at', now(),
  'wal_lsn', pg_current_wal_lsn()::text,
  'database', current_database(),
  'connections_total', (select count(*) from pg_stat_activity where datname = current_database()),
  'connections_active', (select count(*) from pg_stat_activity where datname = current_database() and state = 'active'),
  'xact_commit', sd.xact_commit,
  'xact_rollback', sd.xact_rollback,
  'blks_read', sd.blks_read,
  'blks_hit', sd.blks_hit,
  'tup_inserted', sd.tup_inserted,
  'tup_updated', sd.tup_updated,
  'tup_deleted', sd.tup_deleted,
  'deadlocks', sd.deadlocks,
  'temp_bytes', sd.temp_bytes
)::text
from pg_stat_database sd
where sd.datname = current_database();
"""
    try:
        out = subprocess.check_output(
            ["psql", database_url, "-At", "-v", "ON_ERROR_STOP=1", "-c", sql],
            stderr=subprocess.STDOUT,
            text=True,
            timeout=10,
        )
        return json.loads(out.strip())
    except Exception as e:
        return {"error": str(e)}


def run_interval(args: argparse.Namespace, rest: SupabaseRest, actors: List[DriverActor], interval_sec: int, output_dir: Path) -> Dict[str, Any]:
    metrics = RollingMetrics()
    stop_at = time.monotonic() + args.duration_sec
    sample_path = output_dir / f"interval_{interval_sec}s_samples.jsonl"
    next_driver_due = {actor.user_id: time.monotonic() + random.random() * interval_sec for actor in actors}
    actor_by_user = {actor.user_id: actor for actor in actors}
    db_url = os.getenv("SUPABASE_DB_URL") or os.getenv("DATABASE_URL") or ""

    def rider_loop(kind: str, rate_per_sec: float) -> None:
        if rate_per_sec <= 0:
            return
        delay = 1.0 / rate_per_sec
        while time.monotonic() < stop_at:
            started = time.perf_counter()
            if kind == "nearby":
                ok, detail = rider_nearby_supply(rest, args.center_lat, args.center_lng, args.timeout_sec)
            else:
                ok, detail = create_booking_and_seed(rest, args.center_lat, args.center_lng, args.timeout_sec)
            metrics.record(kind, ok, (time.perf_counter() - started) * 1000.0, detail)
            time.sleep(max(0.0, delay - (time.perf_counter() - started)))

    with sample_path.open("w") as samples, concurrent.futures.ThreadPoolExecutor(max_workers=args.driver_workers) as pool:
        rider_threads = [
            threading.Thread(target=rider_loop, args=("nearby", args.rider_nearby_rps), daemon=True),
            threading.Thread(target=rider_loop, args=("booking", args.rider_booking_rps), daemon=True),
        ]
        for thread in rider_threads:
            thread.start()

        futures: Dict[concurrent.futures.Future[Tuple[bool, str]], float] = {}
        next_sample = time.monotonic()
        while time.monotonic() < stop_at or futures:
            now = time.monotonic()
            if now < stop_at:
                due_users = [uid for uid, due in next_driver_due.items() if due <= now]
                for uid in due_users[: args.max_driver_dispatch_per_tick]:
                    actor = actor_by_user[uid]
                    started = time.perf_counter()
                    fut = pool.submit(upsert_driver_location, rest, actor, args.country_code, args.timeout_sec)
                    futures[fut] = started
                    next_driver_due[uid] = now + interval_sec

            done = [fut for fut in futures if fut.done()]
            for fut in done:
                started = futures.pop(fut)
                try:
                    ok, detail = fut.result()
                except Exception as e:
                    ok, detail = False, str(e)
                metrics.record("driver_location", ok, (time.perf_counter() - started) * 1000.0, detail)

            if now >= next_sample:
                snap = {
                    "interval_sec": interval_sec,
                    "elapsed_sec": round(args.duration_sec - max(0.0, stop_at - now), 2),
                    "client": metrics.snapshot(),
                    "db": db_metric_snapshot(db_url) if db_url else {"error": "SUPABASE_DB_URL/DATABASE_URL not set"},
                    "supabase_dashboard_required": {
                        "cpu": "capture from Supabase dashboard/API during this timestamp",
                        "realtime_connections": "capture from Supabase dashboard/logs during this timestamp",
                        "realtime_fanout": "capture from Supabase dashboard/logs during this timestamp",
                        "slow_query_log": "capture from Supabase Postgres logs during this timestamp",
                    },
                }
                samples.write(json.dumps(snap, default=str) + "\n")
                samples.flush()
                next_sample = now + args.sample_sec
            time.sleep(args.tick_sec)

        for thread in rider_threads:
            thread.join(timeout=1.0)

    summary = metrics.snapshot()
    summary.update(
        {
            "interval_sec": interval_sec,
            "duration_sec": args.duration_sec,
            "drivers": len(actors),
            "target_driver_writes_per_sec": round(len(actors) / interval_sec, 2),
            "sample_file": str(sample_path),
        }
    )
    return summary


def parse_intervals(raw: str) -> List[int]:
    intervals = [int(part.strip()) for part in raw.split(",") if part.strip()]
    if not intervals:
        raise argparse.ArgumentTypeError("at least one interval is required")
    return intervals


def main() -> int:
    parser = argparse.ArgumentParser(description="HeyCaby Supabase 5k-driver load swarm")
    parser.add_argument("--drivers", type=int, default=5000)
    parser.add_argument("--intervals", type=parse_intervals, default=[3, 5, 10], help="Comma-separated seconds, e.g. 3,5,10")
    parser.add_argument("--duration-sec", type=int, default=300)
    parser.add_argument("--country-code", default="NL")
    parser.add_argument("--center-lat", type=float, default=51.9244)
    parser.add_argument("--center-lng", type=float, default=4.4777)
    parser.add_argument("--driver-spread-km", type=float, default=18.0)
    parser.add_argument("--driver-workers", type=int, default=1000)
    parser.add_argument("--max-driver-dispatch-per-tick", type=int, default=10000)
    parser.add_argument("--tick-sec", type=float, default=0.05)
    parser.add_argument("--timeout-sec", type=float, default=10.0)
    parser.add_argument("--sample-sec", type=float, default=10.0)
    parser.add_argument("--rider-nearby-rps", type=float, default=25.0)
    parser.add_argument("--rider-booking-rps", type=float, default=1.0)
    parser.add_argument("--driver-source", choices=["existing", "seed", "manifest"], default="existing")
    parser.add_argument("--manifest", default="build/load/scale_drivers.jsonl")
    parser.add_argument("--seed-batch-size", type=int, default=250)
    parser.add_argument("--output-dir", default="build/load")
    parser.add_argument("--run-label", default="", help="Artifact subdirectory name. Defaults to UTC timestamp.")
    parser.add_argument("--no-write-manifest", action="store_true")
    parser.add_argument(
        "--allow-missing-db-url",
        action="store_true",
        help="Allow runs without SUPABASE_DB_URL/DATABASE_URL. Use only for local harness smoke checks.",
    )
    args = parser.parse_args()

    supabase_url = os.getenv("SUPABASE_URL", "")
    anon_key = os.getenv("SUPABASE_ANON_KEY", "")
    service_key = os.getenv("SUPABASE_SERVICE_KEY", "")
    jwt_secret = os.getenv("SUPABASE_JWT_SECRET", "")
    if not supabase_url or not anon_key or not jwt_secret:
        raise SystemExit("SUPABASE_URL, SUPABASE_ANON_KEY, and SUPABASE_JWT_SECRET are required")
    if args.driver_source in ("existing", "seed") and not service_key:
        raise SystemExit("SUPABASE_SERVICE_KEY is required for --driver-source existing|seed")
    if not (os.getenv("SUPABASE_DB_URL") or os.getenv("DATABASE_URL")) and not args.allow_missing_db_url:
        raise SystemExit(
            "SUPABASE_DB_URL for staging is required for measured load runs. "
            "Use --allow-missing-db-url only for local harness smoke checks."
        )

    if not args.run_label:
        args.run_label = time.strftime("scale_%Y%m%dT%H%M%SZ", time.gmtime())

    output_dir = Path(args.output_dir) / args.run_label
    output_dir.mkdir(parents=True, exist_ok=True)
    rest = SupabaseRest(supabase_url, anon_key, service_key or None)

    if args.driver_source == "manifest":
        actors = load_manifest(Path(args.manifest), jwt_secret, args.center_lat, args.center_lng, args.driver_spread_km)
    elif args.driver_source == "seed":
        rows = rest.seed_drivers(
            count=args.drivers,
            country_code=args.country_code,
            center_lat=args.center_lat,
            center_lng=args.center_lng,
            spread_km=args.driver_spread_km,
            batch_size=args.seed_batch_size,
        )
        actors = actors_from_rows(rows, jwt_secret, args.center_lat, args.center_lng, args.driver_spread_km)
    else:
        rows = rest.fetch_drivers(args.country_code, args.drivers)
        actors = actors_from_rows(rows, jwt_secret, args.center_lat, args.center_lng, args.driver_spread_km)

    actors = actors[: args.drivers]
    if len(actors) < args.drivers:
        raise SystemExit(f"Loaded {len(actors)} drivers; need {args.drivers}")
    if not args.no_write_manifest:
        write_manifest(Path(args.manifest), actors)

    summaries = []
    for interval in args.intervals:
        interval_summary = run_interval(args, rest, actors, interval, output_dir)
        interval_summary_path = output_dir / f"interval_{interval}s_summary.json"
        interval_summary["summary_file"] = str(interval_summary_path)
        interval_summary_path.write_text(json.dumps(interval_summary, indent=2, default=str) + "\n")
        summaries.append(interval_summary)

    summary_path = output_dir / "scale_summary.json"
    summary = {
        "config": vars(args),
        "started_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "summaries": summaries,
    }
    summary_path.write_text(json.dumps(summary, indent=2, default=str) + "\n")
    print(json.dumps(summary, indent=2, default=str))
    print(f"\nWrote {summary_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
