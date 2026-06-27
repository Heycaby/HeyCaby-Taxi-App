# Go backend — archived (Phase E cutover)

As of **Phase E** of the Backend Consolidation Program, production Flutter apps no longer call the AWS Go REST API.

- **Live config:** `app_config.driver_rest_api_base_url` is empty in Supabase prod (`fvrprxguoternoxnyhoj`).
- **Driver hot path:** Supabase RPCs + Edge Functions (`driver-billing-*`, `driver-agent`, etc.).
- **Rider hot path:** Supabase RPCs, Realtime, and direct table access where RLS allows.

This directory is kept for reference, future matching-engine work, and emergency rollback. To restore Go temporarily:

```sql
UPDATE public.app_config
SET value = 'https://api.heycaby.nl'
WHERE key = 'driver_rest_api_base_url';
```

Do **not** delete ECS/task definitions until the soak period in [HEYCABY-V1-MIGRATION-ROADMAP.md](../HEYCABY-V1-MIGRATION-ROADMAP.md) is complete.
