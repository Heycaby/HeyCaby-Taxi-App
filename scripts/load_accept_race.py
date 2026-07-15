#!/usr/bin/env python3
"""Race the canonical production invite-accept RPC with competing Drivers.

This tool intentionally does not create or reset data. Prepare one dedicated
production smoke ride with a live invite for every supplied Driver, then set:

  SUPABASE_URL=https://fvrprxguoternoxnyhoj.supabase.co
  SUPABASE_ANON_KEY=<publishable key>
  DRIVER_ACCEPT_JWTS_JSON='["<driver-a-jwt>","<driver-b-jwt>"]'

The tokens are read only from the environment and are never printed.
"""

import argparse
import base64
import json
import os
import statistics
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass
from typing import Any
from urllib import error, request
from urllib.parse import urlparse


PRODUCTION_PROJECT_REF = "fvrprxguoternoxnyhoj"
STAGING_PROJECT_REF = "fdavszxncggswuiwggcp"
STABLE_LOSER_ERRORS = {
    "race_lost",
    "invite_not_pending",
    "invite_expired",
    "invite_not_found",
    "ride_not_open",
}


@dataclass(frozen=True)
class AcceptResult:
    http_status: int
    elapsed_ms: float
    payload: dict[str, Any]

    @property
    def won(self) -> bool:
        return self.http_status == 200 and self.payload.get("ok") is True

    @property
    def stable_loser(self) -> bool:
        return (
            self.http_status == 200
            and self.payload.get("ok") is False
            and self.payload.get("error") in STABLE_LOSER_ERRORS
        )


def _percentile(values: list[float], pct: float) -> float:
    if not values:
        return 0.0
    ordered = sorted(values)
    index = round((pct / 100.0) * (len(ordered) - 1))
    return ordered[max(0, min(index, len(ordered) - 1))]


def _decode_payload(raw: bytes) -> dict[str, Any]:
    try:
        value = json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError):
        return {"error": "invalid_response"}
    return value if isinstance(value, dict) else {"error": "invalid_response"}


def _accept_once(
    endpoint: str,
    anon_key: str,
    driver_jwt: str,
    ride_id: str,
    timeout_seconds: float,
) -> AcceptResult:
    started = time.perf_counter()
    body = json.dumps({"p_ride_request_id": ride_id}).encode("utf-8")
    req = request.Request(endpoint, method="POST", data=body)
    req.add_header("apikey", anon_key)
    req.add_header("Authorization", f"Bearer {driver_jwt}")
    req.add_header("Content-Type", "application/json")
    try:
        with request.urlopen(req, timeout=timeout_seconds) as response:
            status = response.status
            payload = _decode_payload(response.read())
    except error.HTTPError as exc:
        status = exc.code
        payload = _decode_payload(exc.read())
    except Exception as exc:  # Network failures are reported without secrets.
        status = 0
        payload = {"error": type(exc).__name__}
    return AcceptResult(
        http_status=status,
        elapsed_ms=(time.perf_counter() - started) * 1000.0,
        payload=payload,
    )


def _load_driver_tokens() -> list[str]:
    raw = os.getenv("DRIVER_ACCEPT_JWTS_JSON", "")
    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise SystemExit("DRIVER_ACCEPT_JWTS_JSON must be a JSON array") from exc
    if not isinstance(parsed, list) or len(parsed) < 2:
        raise SystemExit("At least two competing Driver JWTs are required")
    tokens = [token.strip() for token in parsed if isinstance(token, str)]
    if len(tokens) != len(parsed) or any(not token for token in tokens):
        raise SystemExit("Every Driver JWT must be a non-empty string")
    subjects: list[str] = []
    for token in tokens:
        try:
            encoded_payload = token.split(".")[1]
            padded = encoded_payload + "=" * (-len(encoded_payload) % 4)
            payload = json.loads(base64.urlsafe_b64decode(padded))
            subject = payload.get("sub")
        except (IndexError, ValueError, json.JSONDecodeError) as exc:
            raise SystemExit("Every Driver credential must be a JWT") from exc
        if not isinstance(subject, str) or not subject:
            raise SystemExit("Every Driver JWT must contain a subject")
        subjects.append(subject)
    if len(set(subjects)) != len(subjects):
        raise SystemExit("Driver JWTs must represent distinct test Drivers")
    return tokens


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Race competing Drivers against fn_driver_accept_ride_invite",
    )
    parser.add_argument("--ride-id", required=True, help="Dedicated smoke ride UUID")
    parser.add_argument(
        "--fixture-confirmed",
        action="store_true",
        help="Confirm the ride and invites are disposable production smoke fixtures",
    )
    parser.add_argument("--timeout-sec", type=float, default=8.0)
    args = parser.parse_args()

    if not args.fixture_confirmed:
        raise SystemExit(
            "Refusing to mutate production without --fixture-confirmed",
        )

    supabase_url = os.getenv("SUPABASE_URL", "").rstrip("/")
    anon_key = os.getenv("SUPABASE_ANON_KEY", "")
    host = (urlparse(supabase_url).hostname or "").lower()
    if STAGING_PROJECT_REF in host:
        raise SystemExit("Staging is retired; this harness must not use it")
    if PRODUCTION_PROJECT_REF not in host:
        raise SystemExit("SUPABASE_URL must be the HeyCaby production project")
    if not anon_key:
        raise SystemExit("SUPABASE_ANON_KEY is required")

    tokens = _load_driver_tokens()
    endpoint = f"{supabase_url}/rest/v1/rpc/fn_driver_accept_ride_invite"

    results: list[AcceptResult] = []
    with ThreadPoolExecutor(max_workers=len(tokens)) as executor:
        futures = [
            executor.submit(
                _accept_once,
                endpoint,
                anon_key,
                token,
                args.ride_id,
                args.timeout_sec,
            )
            for token in tokens
        ]
        for future in as_completed(futures):
            results.append(future.result())

    winners = sum(result.won for result in results)
    stable_losers = sum(result.stable_loser for result in results)
    unexpected = len(results) - winners - stable_losers
    latencies = [result.elapsed_ms for result in results]
    error_counts: dict[str, int] = {}
    for result in results:
        if result.won:
            continue
        code = str(result.payload.get("error") or f"http_{result.http_status}")
        error_counts[code] = error_counts.get(code, 0) + 1

    passed = winners == 1 and stable_losers == len(results) - 1
    output = {
        "production_project": PRODUCTION_PROJECT_REF,
        "ride_id": args.ride_id,
        "competitors": len(results),
        "winner_count": winners,
        "stable_loser_count": stable_losers,
        "unexpected_count": unexpected,
        "loser_errors": error_counts,
        "latency_ms": {
            "average": round(statistics.mean(latencies), 2),
            "p50": round(_percentile(latencies, 50), 2),
            "p95": round(_percentile(latencies, 95), 2),
            "max": round(max(latencies), 2),
        },
        "passed": passed,
    }
    print(json.dumps(output, indent=2, sort_keys=True))
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
