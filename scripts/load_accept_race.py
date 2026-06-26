#!/usr/bin/env python3
import argparse
import base64
import hashlib
import hmac
import json
import os
import statistics
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import Dict, List, Tuple
from urllib import error, request


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
        "user_metadata": {"user_type": "driver"},
    }
    unsigned = (
        f"{b64url(json.dumps(header, separators=(',', ':')).encode())}."
        f"{b64url(json.dumps(payload, separators=(',', ':')).encode())}"
    ).encode()
    sig = hmac.new(jwt_secret.encode(), unsigned, hashlib.sha256).digest()
    return unsigned.decode() + "." + b64url(sig)


def supabase_reset_ride(supabase_url: str, service_key: str, ride_id: str) -> None:
    patch_url = f"{supabase_url.rstrip('/')}/rest/v1/ride_requests?id=eq.{ride_id}"
    body = json.dumps(
        {
            "status": "pending",
            "driver_id": None,
            "accepted_at": None,
            "updated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        }
    ).encode()
    req = request.Request(patch_url, method="PATCH", data=body)
    req.add_header("apikey", service_key)
    req.add_header("Authorization", f"Bearer {service_key}")
    req.add_header("Content-Type", "application/json")
    req.add_header("Prefer", "return=minimal")
    with request.urlopen(req, timeout=10):
        pass


def accept_once(url: str, token: str, timeout: float) -> Tuple[int, float]:
    started = time.perf_counter()
    req = request.Request(url, method="POST")
    req.add_header("Authorization", f"Bearer {token}")
    try:
        with request.urlopen(req, timeout=timeout) as resp:
            code = resp.status
            resp.read()
    except error.HTTPError as e:
        code = e.code
        e.read()
    except Exception:
        code = 0
    elapsed_ms = (time.perf_counter() - started) * 1000.0
    return code, elapsed_ms


def percentile(values: List[float], pct: float) -> float:
    if not values:
        return 0.0
    idx = max(0, min(len(values) - 1, int(round((pct / 100.0) * (len(values) - 1)))))
    arr = sorted(values)
    return arr[idx]


def main() -> int:
    parser = argparse.ArgumentParser(description="Concurrent ride accept race load test")
    parser.add_argument("--api-base", required=True, help="Backend base URL")
    parser.add_argument("--ride-id", required=True, help="Ride request ID to race on")
    parser.add_argument("--driver-id", required=True, help="Driver UUID for JWT sub")
    parser.add_argument("--rounds", type=int, default=10, help="Number of race rounds")
    parser.add_argument("--concurrency", type=int, default=20, help="Parallel accept requests per round")
    parser.add_argument("--timeout-sec", type=float, default=8.0, help="HTTP timeout per request")
    parser.add_argument(
        "--sleep-between-rounds-sec",
        type=float,
        default=16.0,
        help="Delay between rounds to allow lock TTL expiry",
    )
    args = parser.parse_args()

    jwt_secret = os.getenv("SUPABASE_JWT_SECRET", "")
    supabase_url = os.getenv("SUPABASE_URL", "")
    service_key = os.getenv("SUPABASE_SERVICE_KEY", "")
    if not jwt_secret or not supabase_url or not service_key:
        raise SystemExit("SUPABASE_JWT_SECRET, SUPABASE_URL, SUPABASE_SERVICE_KEY are required env vars")

    token = make_driver_jwt(args.driver_id, jwt_secret)
    accept_url = f"{args.api_base.rstrip('/')}/api/v1/driver/ride/{args.ride_id}/accept"

    all_latencies: List[float] = []
    per_round: List[Dict[str, int]] = []

    for _ in range(args.rounds):
        supabase_reset_ride(supabase_url, service_key, args.ride_id)
        codes: List[int] = []
        with ThreadPoolExecutor(max_workers=args.concurrency) as ex:
            futures = [ex.submit(accept_once, accept_url, token, args.timeout_sec) for _ in range(args.concurrency)]
            for f in as_completed(futures):
                code, elapsed = f.result()
                codes.append(code)
                all_latencies.append(elapsed)
        summary = {
            "200": sum(1 for c in codes if c == 200),
            "409": sum(1 for c in codes if c == 409),
            "other": sum(1 for c in codes if c not in (200, 409)),
        }
        per_round.append(summary)
        time.sleep(args.sleep_between_rounds_sec)

    output = {
        "rounds": args.rounds,
        "concurrency": args.concurrency,
        "per_round": per_round,
        "all_rounds": {
            "total_requests": len(all_latencies),
            "latency_ms_avg": round(statistics.mean(all_latencies), 2) if all_latencies else 0.0,
            "latency_ms_p50": round(percentile(all_latencies, 50), 2),
            "latency_ms_p95": round(percentile(all_latencies, 95), 2),
            "latency_ms_p99": round(percentile(all_latencies, 99), 2),
            "success_200": sum(r["200"] for r in per_round),
            "conflict_409": sum(r["409"] for r in per_round),
            "other": sum(r["other"] for r in per_round),
            "rounds_with_exactly_one_winner": sum(1 for r in per_round if r["200"] == 1),
        },
    }
    print(json.dumps(output, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

