# Redis in HeyCaby (backend)

Redis is **required in production**. The Go API uses it for:

| Capability | Redis usage |
|------------|--------------|
| **Driver online & map** | GEO set `drivers:{CC}` — heartbeat refreshes position + TTL (`UpsertDriverLocation`, ZREM when offline). |
| **Nearby matching** | `GeoRadius` for riders searching for drivers (`use_redis_locations` in app flags). |
| **Ride accept race** | `SET NX` lock `ride:{id}:accept_lock` so only one driver wins (`RideService.Accept`). |
| **Fast status** | Ephemeral `drivers:{CC}:{id}:status` with TTL alongside Postgres. |

If Redis is missing or unreachable and **`REDIS_OPTIONAL` is not set**, the process **exits on startup** so ECS/Kubernetes will restart until Redis is wired correctly — no silent “run without second brain”.

## Environment variables

| Variable | Required | Meaning |
|----------|----------|---------|
| **`REDIS_URL`** | Yes (prod) | Connection URI. Examples: `redis://localhost:6379`, `rediss://master.xxx.cache.amazonaws.com:6379` (TLS). |
| **`REDIS_OPTIONAL`** | No | Set to **`true`** only on a developer machine without Redis. **Never** set this in AWS/ECS. |

## Your side (AWS)

1. **ElastiCache for Redis** (same **VPC** as ECS tasks).
2. **Security groups**: ECS task SG → allow outbound TCP **6379** (or **6380** if your cache uses that) to ElastiCache SG; ElastiCache SG → inbound from ECS SG only.
3. **Auth**: TLS (`rediss://`) + ACL password if enabled — put the full URL in **Secrets Manager** and map it to **`REDIS_URL`** in the task definition.
4. After deploy, verify **`GET /health/ready`** with **`strict=true`** (if exposed) shows **`redis":"ok"`** when flags require Redis.

## Local development

- Run Redis (`docker run -p 6379:6379 redis:7`) **or**
- Set **`REDIS_OPTIONAL=true`** to boot the API without Redis (matching/accept flows that need Redis will error at runtime).

See also `docs/BACKEND_SIMULATION_SMOKE_TEST_MASTER.md` for strict readiness checks.
