# HeyCaby Rider App — Secure Supabase Backend Implementation Guide

> **Audience:** Your developer.  
> **Goal:** Build a privacy-respecting, GDPR-aligned, App Store–safe backend for a Dutch taxi rider app.  
> **Core principle:** Anonymous by default → upgrade to permanent account only when the user wants features that require it.

---

## How Rider Identity Works (Mental Model First)

There are **not two separate account systems**. There is **one account with two states**:

| State | Trigger | What they can do |
|---|---|---|
| **Guest** (anonymous Supabase user) | App first open | Book rides, enter a call name per trip |
| **Permanent** (upgraded anonymous user) | User opts in for features | + Save favorite drivers, save addresses |

A guest rider gets a real Supabase `auth.uid()` from the first app open. No email, no phone, no friction. When they later provide an email to unlock features, the **same account is upgraded** — nothing is duplicated or migrated.

---

## Phase 1 — Foundation: Anonymous Auth + Core Schema

### Step 1.1 — Project Setup

- Create your Supabase project in the **Frankfurt (eu-central-1)** region. Data stays in the EU, aligned with your Dutch market and GDPR requirements.
- In **Authentication → Settings**, enable **Anonymous Sign-Ins**.
- Enable **CAPTCHA protection** on anonymous sign-ins (Supabase recommends this because anonymous sign-ins create real DB users and can be abused at scale).
- Set rate limits on anonymous sign-ins to prevent abuse.
- In **Project Settings → API**, switch to the new `sb_publishable_...` and `sb_secret_...` key format. Rotate the legacy keys.

### Step 1.2 — Schema Layout

Create four schemas to separate concerns:

```sql
CREATE SCHEMA IF NOT EXISTS private;
CREATE SCHEMA IF NOT EXISTS security;
-- "public" already exists in Supabase
```

- `public` — API-facing tables with RLS. Exposed via the auto-generated REST API.
- `private` — Sensitive PII tables. Never directly accessible from the mobile client.
- `security` — Helper functions and authorization logic.

### Step 1.3 — Rider Accounts Table

```sql
CREATE TABLE public.rider_accounts (
  id              UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  account_kind    TEXT NOT NULL DEFAULT 'guest' CHECK (account_kind IN ('guest', 'permanent')),
  locale          TEXT,
  timezone        TEXT,
  marketing_opt_in BOOLEAN NOT NULL DEFAULT FALSE,
  ai_consent      BOOLEAN NOT NULL DEFAULT FALSE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_seen_at    TIMESTAMPTZ,
  upgraded_at     TIMESTAMPTZ
);

ALTER TABLE public.rider_accounts ENABLE ROW LEVEL SECURITY;

-- Riders can only read and update their own row
CREATE POLICY "rider_accounts_select_own"
  ON public.rider_accounts FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "rider_accounts_update_own"
  ON public.rider_accounts FOR UPDATE
  USING (auth.uid() = id);
```

**Important rules for this table:**
- Primary key is `auth.users.id` — never email. Email is an identity attribute, not a durable application key.
- Do not store the rider's call name here as a default. It belongs on the ride (see Step 1.5).
- Do not use `raw_user_meta_data` or `user_metadata` for any security decisions — Supabase explicitly warns these are user-editable.

### Step 1.4 — Auto-Create Account on Sign-Up

```sql
CREATE OR REPLACE FUNCTION security.on_auth_user_created()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, security
AS $$
BEGIN
  INSERT INTO public.rider_accounts (id, account_kind)
  VALUES (NEW.id, CASE WHEN (NEW.raw_app_meta_data->>'is_anonymous')::boolean THEN 'guest' ELSE 'permanent' END)
  ON CONFLICT (id) DO NOTHING; -- idempotent
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION security.on_auth_user_created();
```

**⚠️ Keep this trigger tiny and idempotent.** Supabase warns that a failing signup trigger blocks the entire sign-up flow.

> **⚠️ Caution — SECURITY DEFINER placement and least privilege:** All `SECURITY DEFINER` functions in this guide are placed in the `security` schema, which is not exposed via the auto-generated PostgREST API. This is intentional. Never create `SECURITY DEFINER` functions in the `public` schema — PostgREST exposes `public` by default, meaning a `SECURITY DEFINER` function there could be called by any authenticated client and would run with the permissions of its creator (usually the `postgres` superuser role).
>
> Trigger functions invoked internally by Postgres (like this one) do not need `REVOKE` statements — they are not callable via RPC and Postgres manages their execution directly. However, **any `SECURITY DEFINER` function that is RPC-callable** (i.e. exposed intentionally or accidentally via `public`) must have execute privileges tightly controlled. For those functions, apply least privilege explicitly, including the full argument signature in the statement:
>
> ```sql
> -- For RPC-exposed SECURITY DEFINER functions only (not trigger functions)
> REVOKE ALL ON FUNCTION public.some_rpc_function(uuid, text) FROM PUBLIC;
> GRANT EXECUTE ON FUNCTION public.some_rpc_function(uuid, text) TO authenticated;
> ```
>
> The rule of thumb: if a function is in `security` and wired only to a trigger, no `REVOKE` is needed. If a function is in `public` and callable by clients, apply `REVOKE` + targeted `GRANT` with the exact argument list.

### Step 1.5 — Ride Requests Table

```sql
-- Requires PostGIS extension
CREATE EXTENSION IF NOT EXISTS postgis;

CREATE TABLE public.ride_requests (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  rider_id        UUID NOT NULL REFERENCES auth.users(id),
  pickup_point    GEOGRAPHY(POINT, 4326) NOT NULL,
  dropoff_point   GEOGRAPHY(POINT, 4326) NOT NULL,
  pickup_address  TEXT,
  dropoff_address TEXT,
  service_tier    TEXT,
  price_snapshot  JSONB,
  ride_state      TEXT NOT NULL DEFAULT 'pending'
                    CHECK (ride_state IN ('pending','matching','active','completed','cancelled')),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX ON public.ride_requests USING GIST (pickup_point);
CREATE INDEX ON public.ride_requests USING GIST (dropoff_point);
CREATE INDEX ON public.ride_requests (rider_id);

ALTER TABLE public.ride_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "ride_requests_rider_owns"
  ON public.ride_requests FOR ALL
  USING (auth.uid() = rider_id);
```

Use `GEOGRAPHY(POINT, 4326)` with a spatial index — not plain decimal lat/lng columns. PostGIS is built for efficient geo queries at scale.

### Step 1.6 — Ride Contact Snapshots (Private, Sensitive)

This is where the rider's **"What should the driver call you?"** answer lives — tied to the ride, not the profile.

```sql
CREATE TABLE private.ride_contact_snapshots (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id         UUID NOT NULL REFERENCES public.ride_requests(id) ON DELETE CASCADE,
  call_name       TEXT NOT NULL,
  notes           TEXT,
  purge_after     TIMESTAMPTZ, -- set when ride reaches a terminal state
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- No direct client RLS — access only via RPC functions
-- Drivers and riders access this through controlled server-side calls only
```

**Never expose `private.*` tables directly to the client API.** Access them only through `SECURITY DEFINER` RPC functions with explicit permission checks.

### Step 1.7 — Ride Creation RPC (Single Transaction)

Do not allow the client to write directly to multiple tables. Use a single controlled RPC.

> **Design note — schema placement:** This function is placed in the `security` schema to keep `SECURITY DEFINER` logic out of `public`. To expose it as a callable RPC, grant execute to the `authenticated` role explicitly. If you prefer to keep it in `public` for simpler PostgREST routing, you must add a `REVOKE`/`GRANT` block (see Step 1.4 caution) and treat every input as untrusted — `auth.uid()` is always stamped server-side, and no caller-supplied rider identity is ever accepted.

```sql
CREATE OR REPLACE FUNCTION security.create_ride_request(
  p_pickup_lat    FLOAT,
  p_pickup_lng    FLOAT,
  p_dropoff_lat   FLOAT,
  p_dropoff_lng   FLOAT,
  p_pickup_addr   TEXT,
  p_dropoff_addr  TEXT,
  p_call_name     TEXT,
  p_service_tier  TEXT DEFAULT 'standard'
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private, security
AS $$
DECLARE
  v_ride_id UUID;
BEGIN
  -- Always stamp auth.uid() server-side — never trust client-provided rider_id
  INSERT INTO public.ride_requests (rider_id, pickup_point, dropoff_point, pickup_address, dropoff_address, service_tier)
  VALUES (
    auth.uid(),
    ST_SetSRID(ST_MakePoint(p_pickup_lng, p_pickup_lat), 4326)::geography,
    ST_SetSRID(ST_MakePoint(p_dropoff_lng, p_dropoff_lat), 4326)::geography,
    p_pickup_addr,
    p_dropoff_addr,
    p_service_tier
  )
  RETURNING id INTO v_ride_id;

  INSERT INTO private.ride_contact_snapshots (ride_id, call_name)
  VALUES (v_ride_id, p_call_name);

  RETURN v_ride_id;
END;
$$;

-- Expose to authenticated riders only (with full argument signature)
REVOKE ALL ON FUNCTION security.create_ride_request(float, float, float, float, text, text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION security.create_ride_request(float, float, float, float, text, text, text, text) TO authenticated;
```

The call name is always trip-scoped. The client sends it at booking time; it never gets written to the rider's profile unless they explicitly save it later.

---

## Phase 2 — Optional Feature Unlock: Email → Permanent Account

### Step 2.1 — The Upgrade Flow (Not a New Account)

When a rider taps "Save Favorite Driver" or "Save Home Address" and has no email on file, show the prompt in the app UI. The backend flow is:

1. Call Supabase Auth's `linkIdentity()` with the email OTP method — this **upgrades the existing anonymous session**, not creates a new one.
2. Supabase sends a magic link / OTP to the email.
3. On verification, update `rider_accounts.account_kind = 'permanent'` and set `upgraded_at = NOW()`.

**Never create a parallel email-based profile.** If the email already exists on another account, build an explicit merge flow rather than silently overwriting.

### Step 2.2 — Favorites Table (Permanent Riders Only)

```sql
CREATE TABLE public.favorite_drivers (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  rider_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  driver_id   UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (rider_id, driver_id)
);

ALTER TABLE public.favorite_drivers ENABLE ROW LEVEL SECURITY;

-- Only permanent riders can use this table.
-- Uses rider_accounts.account_kind as the authoritative check — more reliable than
-- the JWT is_anonymous claim, which can lag by up to one token validity window after upgrade.
CREATE POLICY "favorites_permanent_riders_only"
  ON public.favorite_drivers FOR ALL
  USING (
    auth.uid() = rider_id
    AND EXISTS (
      SELECT 1 FROM public.rider_accounts
      WHERE id = auth.uid()
        AND account_kind = 'permanent'
    )
  );
```

**Use a RESTRICTIVE policy** (not just permissive) to ensure anonymous users cannot bypass the check through a permissive OR-combination.

After a rider upgrades their account, the app must call `supabase.auth.refreshSession()` immediately. The JWT `is_anonymous` claim can remain stale for up to one token validity window — the `rider_accounts.account_kind` database check is the reliable enforcement layer regardless of token state.

### Step 2.3 — Enforce 10 Favorites Cap

```sql
CREATE OR REPLACE FUNCTION security.enforce_favorites_cap()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, security
AS $$
BEGIN
  IF (SELECT COUNT(*) FROM public.favorite_drivers WHERE rider_id = NEW.rider_id) >= 10 THEN
    RAISE EXCEPTION 'Maximum of 10 favorite drivers allowed.';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER enforce_favorites_cap
  BEFORE INSERT ON public.favorite_drivers
  FOR EACH ROW EXECUTE FUNCTION security.enforce_favorites_cap();
```

Business rules belong in the database — they cannot drift between client versions.

### Step 2.4 — Saved Places (Private, Permanent Riders Only)

```sql
-- Requires pg_jsonschema for validation
CREATE EXTENSION IF NOT EXISTS pg_jsonschema;

CREATE TABLE private.saved_places (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  rider_id        UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  label           TEXT NOT NULL CHECK (label IN ('home', 'work', 'gym', 'custom')),
  display_name    TEXT NOT NULL,
  address_json    JSONB NOT NULL,
  point           GEOGRAPHY(POINT, 4326) NOT NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (rider_id, label)
);
```

Expose saved places to the client only through a narrowly scoped RPC or `SECURITY INVOKER` view — never direct table access. Validate `address_json` with `pg_jsonschema` before insertion so malformed blobs never land in the database.

---

## Phase 3 — AI Consent Gate (Required for App Store)

This is the permanent fix for the Apple App Review issue. Build the enforcement into the backend itself, not just the UI.

### Step 3.1 — Consent Ledger

```sql
CREATE TABLE public.ai_consents (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  rider_id          UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  provider          TEXT NOT NULL,       -- e.g. 'openai', 'anthropic'
  disclosure_version TEXT NOT NULL,
  scope             TEXT NOT NULL,       -- e.g. 'dispatch_optimization'
  consented_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  revoked_at        TIMESTAMPTZ
);

ALTER TABLE public.ai_consents ENABLE ROW LEVEL SECURITY;

CREATE POLICY "ai_consents_own"
  ON public.ai_consents FOR ALL
  USING (auth.uid() = rider_id);
```

### Step 3.2 — AI Dispatch Audit Log (Private)

```sql
CREATE TABLE private.ai_dispatch_log (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  rider_id        UUID NOT NULL REFERENCES auth.users(id),
  provider        TEXT NOT NULL,
  provider_req_id TEXT,
  data_categories TEXT[] NOT NULL,    -- e.g. ARRAY['location','call_name']
  redacted        BOOLEAN NOT NULL DEFAULT FALSE,
  dispatched_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

This is your App Review evidence trail and GDPR audit trail. All AI provider secrets must live in **Edge Function environment variables or Supabase Vault** — never in the app bundle.

### Step 3.3 — Server-Side Consent Check

Before any Edge Function calls an external AI provider, it must check:

```typescript
// In your Edge Function
const { data: consent } = await supabaseAdmin
  .from('ai_consents')
  .select('id')
  .eq('rider_id', userId)
  .eq('provider', 'your_provider')
  .is('revoked_at', null)
  .single();

if (!consent) {
  return new Response(JSON.stringify({ error: 'AI consent required' }), { status: 403 });
}
```

---

## Phase 4 — Privacy & Data Retention

### Step 4.1 — Mark Contact Snapshots for Purge on Trip Completion

```sql
CREATE OR REPLACE FUNCTION security.on_ride_terminal_state()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private, security
AS $$
BEGIN
  IF NEW.ride_state IN ('completed', 'cancelled') AND OLD.ride_state NOT IN ('completed', 'cancelled') THEN
    UPDATE private.ride_contact_snapshots
    SET purge_after = NOW() + INTERVAL '30 days'  -- adjust to your retention policy
    WHERE ride_id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_ride_terminal_state
  AFTER UPDATE OF ride_state ON public.ride_requests
  FOR EACH ROW EXECUTE FUNCTION security.on_ride_terminal_state();
```

The 30-day window is a placeholder — your legal/business decision. But the **database must enforce whatever schedule you decide on**.

### Step 4.2 — Scheduled Cleanup Jobs (pg_cron)

```sql
-- Purge contact snapshots past their retention window
SELECT cron.schedule(
  'purge-expired-contact-snapshots',
  '0 3 * * *',   -- 3am daily
  $$DELETE FROM private.ride_contact_snapshots WHERE purge_after < NOW()$$
);

-- Purge stale anonymous users (Supabase does NOT auto-delete them)
-- Customize the interval based on your guest session policy
SELECT cron.schedule(
  'purge-stale-anonymous-users',
  '0 4 * * *',
  $$
    DELETE FROM auth.users
    WHERE id IN (
      SELECT id FROM public.rider_accounts
      WHERE account_kind = 'guest'
        AND last_seen_at < NOW() - INTERVAL '90 days'  -- your policy
    )
  $$
);
```

**Critical note:** Supabase anonymous sessions do not expire automatically. You must implement cleanup yourself.

> **⚠️ Caution — coordinate purge with product expectations:** Before running the anonymous-user purge job in production, answer these questions with your product team and document the answers:
>
> - **Device persistence expectation:** If a guest rider closes the app and reopens it days later, do they expect their session to still exist? If yes, your cleanup window must be longer than the realistic re-engagement window — 90 days may still be too short for irregular riders.
> - **Active trip guard:** The purge query above checks `last_seen_at` on `rider_accounts`. Before deleting, also verify the user has no ride in a non-terminal state. Add this guard:
>
>   ```sql
>   DELETE FROM auth.users
>   WHERE id IN (
>     SELECT ra.id FROM public.rider_accounts ra
>     WHERE ra.account_kind = 'guest'
>       AND ra.last_seen_at < NOW() - INTERVAL '90 days'
>       AND NOT EXISTS (
>         SELECT 1 FROM public.ride_requests rr
>         WHERE rr.rider_id = ra.id
>           AND rr.ride_state NOT IN ('completed', 'cancelled')
>       )
>   );
>   ```
>
> - **`last_seen_at` must be maintained:** The cleanup job is only as accurate as the heartbeat that updates `last_seen_at`. Make sure your Flutter app writes to this field on app foreground / session resume, otherwise all guest accounts will appear stale regardless of real activity.
> - **Run in dry-run first:** Before scheduling, run the `SELECT` version of the query (without `DELETE`) on production data to count how many rows would be affected. Only schedule the delete once the numbers look expected.

### Step 4.3 — Retention Classes Reference

| Data category | Retention rule | Mechanism |
|---|---|---|
| Ride call name | Trip duration + 30 days (adjustable) | `purge_after` + pg_cron |
| Pickup/dropoff location | Trip + dispute window (e.g. 90 days) | Scheduled delete |
| Favorite drivers | Until user deletes or account erased | User-initiated + account delete cascade |
| Saved places | Until user deletes or account erased | User-initiated + account delete cascade |
| Stale guest accounts | 90 days of inactivity (adjustable) | pg_cron scheduled purge |
| AI consent records | Duration of account + legal hold | Manual / legal process |

---

## Phase 5 — Production Hardening

### Step 5.1 — Key and Access Discipline

- Mobile app uses **only the publishable key** (`sb_publishable_...`) against the HTTPS API.
- **Never** ship direct Postgres connection strings, service-role keys, or secret keys in the app bundle.
- Service-role keys stay in Edge Functions and backend services only — they bypass RLS entirely.
- Use **Network Restrictions** for any bastion hosts or CI runners with direct DB access.

### Step 5.2 — Prevent Accidentally Unprotected Tables

```sql
-- Auto-enable RLS on any new table created in the public schema
CREATE OR REPLACE FUNCTION security.auto_enable_rls()
RETURNS event_trigger
LANGUAGE plpgsql
AS $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN SELECT * FROM pg_event_trigger_ddl_commands() WHERE command_tag = 'CREATE TABLE'
  LOOP
    IF r.schema_name = 'public' THEN
      -- Use objid -> relname rather than object_identity to avoid qualified-name quoting issues
      EXECUTE format(
        'ALTER TABLE %I.%I ENABLE ROW LEVEL SECURITY',
        r.schema_name,
        (SELECT relname FROM pg_class WHERE oid = r.objid)
      );
    END IF;
  END LOOP;
END;
$$;

CREATE EVENT TRIGGER auto_enable_rls_trigger
  ON ddl_command_end
  WHEN TAG IN ('CREATE TABLE')
  EXECUTE FUNCTION security.auto_enable_rls();
```

> **Note:** The `objid → relname` lookup via `pg_class` is safer than using `object_identity` directly, which returns a fully-qualified name string that `%I` cannot cleanly interpolate. Test locally with `SELECT relrowsecurity FROM pg_class WHERE relname = 'your_test_table'` after creating a table to confirm the trigger fires correctly. Treat this as a safety net — every migration file should still include an explicit `ENABLE ROW LEVEL SECURITY` statement rather than relying solely on this trigger.

### Step 5.3 — Staff / Admin Access (Custom Claims + MFA)

- Add custom staff claims via a **Custom Access Token Hook** in Supabase Auth settings.
- Require `aal2` (MFA verified) for sensitive admin workflows: identity lookups, manual refunds, broad ride-history access.
- Use Supabase organization roles aggressively — most developers should not have Owner or Administrator access.

### Step 5.4 — Backup and Observability

- Enable **Point-in-Time Recovery (PITR)** if the app is revenue-critical.
- Enable **Auth Audit Logs** in Supabase Dashboard.
- Enable `pgaudit` extension for database-level query visibility.
- Enable **SSL enforcement** for all direct database connections.

### Step 5.5 — Storage (If You Use Profile Photos)

- Use **private Storage buckets** with owner-scoped policies.
- Service keys bypass Storage RLS — keep them server-side only.
- Remember: database backups do not restore deleted Storage objects. Only metadata is in the DB.

---

## Phase 6 — Testing and Deployment Discipline

- Manage all schema changes with **Supabase CLI migrations** (`supabase db diff`, `supabase migration new`). Treat the database as code.
- Write **pgTAP tests** for all RLS policies and critical functions before deploying.
- Run `plpgsql_check` to lint PL/pgSQL functions for errors.
- Run **Supabase Security Advisor** as part of every production deployment checklist.
- On mobile: no sensitive values in logs, use platform keychain/keystore for tokens, all traffic over TLS.

---

## Implementation Order Checklist

```
Phase 1 — Core (do before first real user)
  [ ] Supabase project in Frankfurt region
  [ ] Anonymous auth enabled with CAPTCHA
  [ ] Publishable/secret keys configured
  [ ] public.rider_accounts + RLS
  [ ] on_auth_user_created trigger
  [ ] public.ride_requests with PostGIS + RLS
  [ ] private.ride_contact_snapshots
  [ ] public.create_ride_request() RPC
  [ ] Auto-enable RLS event trigger

Phase 2 — Optional Features (before favorite/saved-place features ship)
  [ ] Email OTP upgrade flow in Flutter (linkIdentity)
  [ ] public.favorite_drivers + permanent-only RLS
  [ ] 10-favorites cap trigger
  [ ] private.saved_places + RPC accessor
  [ ] rider_accounts.account_kind upgrade on email verify

Phase 3 — AI Consent (before App Store resubmission)
  [ ] public.ai_consents + RLS
  [ ] private.ai_dispatch_log
  [ ] Edge Function consent check before any AI call
  [ ] Provider secrets in Vault / Edge Function env vars
  [ ] Disclosure modal in app with version tracking

Phase 4 — Retention
  [ ] on_ride_terminal_state trigger sets purge_after
  [ ] pg_cron jobs for contact snapshot purge
  [ ] pg_cron job for stale anonymous user purge
  [ ] Retention schedule documented and approved

Phase 5 — Hardening (before public launch)
  [ ] PITR enabled
  [ ] Auth Audit Logs enabled
  [ ] pgaudit enabled
  [ ] SSL enforcement on
  [ ] Network restrictions for direct DB access
  [ ] MFA enforced for staff/admin roles
  [ ] pgTAP RLS tests passing
  [ ] Security Advisor clean
```

---

## Resolved Decisions (v1)

These decisions are approved defaults for implementation unless explicitly changed later.

1. **Call name session scope** — Persist call name for the duration of an active trip (including app relaunch). Treat call name as trip-scoped data stored in `private.ride_contact_snapshots`. Allow local UX prefill on the same device, but do not treat that prefill as backend profile identity.
2. **Guest session scope** — Device-scoped anonymous identity by default. Keep one anonymous Supabase user per app install/session lifecycle, not per booking.
3. **Retention windows** — Use the following baseline:
   - ride contact snapshot (`call_name`, notes): 30 days after terminal ride state
   - trip location detail for operations/disputes: 90 days
   - stale guest cleanup: 180 days inactivity (with active-ride guard)
4. **AI providers** — Policy-facing provider is OpenAI (ChatGPT). If a gateway is used operationally, legal/privacy disclosures remain centered on OpenAI processing for rider AI support.
5. **Cross-border transfers** — Assume transfers may occur outside EEA for AI/support processing. Require DPA + SCCs + transfer assessment, and keep consent/privacy disclosure versioned and in sync.

---

## Open Decisions (Require Your Input Before Implementation)

These are policy decisions — the architecture supports any choice, but they must be made explicitly:

1. **Call name session scope** — Should the rider's entered call name survive an app relaunch within the same active trip, or reset on every app open?
2. **Guest session scope** — Is guest identity device-scoped (persists on same device across app relaunches) or trip-scoped (new anonymous user per booking)?
3. **Exact retention windows** — Confirm the business-approved durations for trip contact data, location data, and stale guest cleanup.
4. **AI providers** — Which third-party AI providers will you use? Each needs a proper DPA, the correct EU data transfer basis (adequacy or SCCs), and a separate consent disclosure version.
5. **Cross-border transfers** — If any AI provider or support processor is outside the EEA, document the transfer mechanism in your privacy policy and vendor contracts.
# HeyCaby Rider App — Secure Supabase Backend Implementation Guide

> **Audience:** Your developer.  
> **Goal:** Build a privacy-respecting, GDPR-aligned, App Store–safe backend for a Dutch taxi rider app.  
> **Core principle:** Anonymous by default → upgrade to permanent account only when the user wants features that require it.

---

## How Rider Identity Works (Mental Model First)

There are **not two separate account systems**. There is **one account with two states**:

| State | Trigger | What they can do |
|---|---|---|
| **Guest** (anonymous Supabase user) | App first open | Book rides, enter a call name per trip |
| **Permanent** (upgraded anonymous user) | User opts in for features | + Save favorite drivers, save addresses |

A guest rider gets a real Supabase `auth.uid()` from the first app open. No email, no phone, no friction. When they later provide an email to unlock features, the **same account is upgraded** — nothing is duplicated or migrated.

---

## Phase 1 — Foundation: Anonymous Auth + Core Schema

### Step 1.1 — Project Setup

- Create your Supabase project in the **Frankfurt (eu-central-1)** region. Data stays in the EU, aligned with your Dutch market and GDPR requirements.
- In **Authentication → Settings**, enable **Anonymous Sign-Ins**.
- Enable **CAPTCHA protection** on anonymous sign-ins (Supabase recommends this because anonymous sign-ins create real DB users and can be abused at scale).
- Set rate limits on anonymous sign-ins to prevent abuse.
- In **Project Settings → API**, switch to the new `sb_publishable_...` and `sb_secret_...` key format. Rotate the legacy keys.

### Step 1.2 — Schema Layout

Create four schemas to separate concerns:

```sql
CREATE SCHEMA IF NOT EXISTS private;
CREATE SCHEMA IF NOT EXISTS security;
-- "public" already exists in Supabase
```

- `public` — API-facing tables with RLS. Exposed via the auto-generated REST API.
- `private` — Sensitive PII tables. Never directly accessible from the mobile client.
- `security` — Helper functions and authorization logic.

### Step 1.3 — Rider Accounts Table

```sql
CREATE TABLE public.rider_accounts (
  id              UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  account_kind    TEXT NOT NULL DEFAULT 'guest' CHECK (account_kind IN ('guest', 'permanent')),
  locale          TEXT,
  timezone        TEXT,
  marketing_opt_in BOOLEAN NOT NULL DEFAULT FALSE,
  ai_consent      BOOLEAN NOT NULL DEFAULT FALSE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_seen_at    TIMESTAMPTZ,
  upgraded_at     TIMESTAMPTZ
);

ALTER TABLE public.rider_accounts ENABLE ROW LEVEL SECURITY;

-- Riders can only read and update their own row
CREATE POLICY "rider_accounts_select_own"
  ON public.rider_accounts FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "rider_accounts_update_own"
  ON public.rider_accounts FOR UPDATE
  USING (auth.uid() = id);
```

**Important rules for this table:**
- Primary key is `auth.users.id` — never email. Email is an identity attribute, not a durable application key.
- Do not store the rider's call name here as a default. It belongs on the ride (see Step 1.5).
- Do not use `raw_user_meta_data` or `user_metadata` for any security decisions — Supabase explicitly warns these are user-editable.

### Step 1.4 — Auto-Create Account on Sign-Up

```sql
CREATE OR REPLACE FUNCTION security.on_auth_user_created()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, security
AS $$
BEGIN
  INSERT INTO public.rider_accounts (id, account_kind)
  VALUES (NEW.id, CASE WHEN (NEW.raw_app_meta_data->>'is_anonymous')::boolean THEN 'guest' ELSE 'permanent' END)
  ON CONFLICT (id) DO NOTHING; -- idempotent
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION security.on_auth_user_created();
```

**⚠️ Keep this trigger tiny and idempotent.** Supabase warns that a failing signup trigger blocks the entire sign-up flow.

> **⚠️ Caution — SECURITY DEFINER placement:** Keep `SECURITY DEFINER` functions in a non-exposed schema (for example `security`), not `public`. In Supabase, `public` is API-exposed by default.
>
> For any `SECURITY DEFINER` function that can be called directly (RPC), apply least privilege:
>
> ```sql
> REVOKE ALL ON FUNCTION security.some_function(...) FROM PUBLIC;
> -- GRANT EXECUTE only to the roles that truly need it.
> ```
>
> For trigger-only functions, Postgres invokes them via the trigger; they do not need broad runtime execute grants.

### Step 1.5 — Ride Requests Table

```sql
-- Requires PostGIS extension
CREATE EXTENSION IF NOT EXISTS postgis;

CREATE TABLE public.ride_requests (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  rider_id        UUID NOT NULL REFERENCES auth.users(id),
  pickup_point    GEOGRAPHY(POINT, 4326) NOT NULL,
  dropoff_point   GEOGRAPHY(POINT, 4326) NOT NULL,
  pickup_address  TEXT,
  dropoff_address TEXT,
  service_tier    TEXT,
  price_snapshot  JSONB,
  ride_state      TEXT NOT NULL DEFAULT 'pending'
                    CHECK (ride_state IN ('pending','matching','active','completed','cancelled')),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX ON public.ride_requests USING GIST (pickup_point);
CREATE INDEX ON public.ride_requests USING GIST (dropoff_point);
CREATE INDEX ON public.ride_requests (rider_id);

ALTER TABLE public.ride_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "ride_requests_rider_owns"
  ON public.ride_requests FOR ALL
  USING (auth.uid() = rider_id);
```

Use `GEOGRAPHY(POINT, 4326)` with a spatial index — not plain decimal lat/lng columns. PostGIS is built for efficient geo queries at scale.

### Step 1.6 — Ride Contact Snapshots (Private, Sensitive)

This is where the rider's **"What should the driver call you?"** answer lives — tied to the ride, not the profile.

```sql
CREATE TABLE private.ride_contact_snapshots (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id         UUID NOT NULL REFERENCES public.ride_requests(id) ON DELETE CASCADE,
  call_name       TEXT NOT NULL,
  notes           TEXT,
  purge_after     TIMESTAMPTZ, -- set when ride reaches a terminal state
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- No direct client RLS — access only via RPC functions
-- Drivers and riders access this through controlled server-side calls only
```

**Never expose `private.*` tables directly to the client API.** Access them only through `SECURITY DEFINER` RPC functions with explicit permission checks.

### Step 1.7 — Ride Creation RPC (Single Transaction)

Do not allow the client to write directly to multiple tables. Use a single controlled RPC:

```sql
CREATE OR REPLACE FUNCTION security.create_ride_request(
  p_pickup_lat    FLOAT,
  p_pickup_lng    FLOAT,
  p_dropoff_lat   FLOAT,
  p_dropoff_lng   FLOAT,
  p_pickup_addr   TEXT,
  p_dropoff_addr  TEXT,
  p_call_name     TEXT,
  p_service_tier  TEXT DEFAULT 'standard'
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private, security
AS $$
DECLARE
  v_ride_id UUID;
BEGIN
  -- Always stamp auth.uid() server-side — never trust client-provided rider_id
  INSERT INTO public.ride_requests (rider_id, pickup_point, dropoff_point, pickup_address, dropoff_address, service_tier)
  VALUES (
    auth.uid(),
    ST_SetSRID(ST_MakePoint(p_pickup_lng, p_pickup_lat), 4326)::geography,
    ST_SetSRID(ST_MakePoint(p_dropoff_lng, p_dropoff_lat), 4326)::geography,
    p_pickup_addr,
    p_dropoff_addr,
    p_service_tier
  )
  RETURNING id INTO v_ride_id;

  INSERT INTO private.ride_contact_snapshots (ride_id, call_name)
  VALUES (v_ride_id, p_call_name);

  RETURN v_ride_id;
END;
$$;
```

The call name is always trip-scoped. The client sends it at booking time; it never gets written to the rider's profile unless they explicitly save it later.

> If you expose this as an RPC, grant execute explicitly to the intended caller role only.

---

## Phase 2 — Optional Feature Unlock: Email → Permanent Account

### Step 2.1 — The Upgrade Flow (Not a New Account)

When a rider taps "Save Favorite Driver" or "Save Home Address" and has no email on file, show the prompt in the app UI. The backend flow is:

1. Call Supabase Auth's `linkIdentity()` with the email OTP method — this **upgrades the existing anonymous session**, not creates a new one.
2. Supabase sends a magic link / OTP to the email.
3. On verification, update `rider_accounts.account_kind = 'permanent'` and set `upgraded_at = NOW()`.

**Never create a parallel email-based profile.** If the email already exists on another account, build an explicit merge flow rather than silently overwriting.

### Step 2.2 — Favorites Table (Permanent Riders Only)

```sql
CREATE TABLE public.favorite_drivers (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  rider_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  driver_id   UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (rider_id, driver_id)
);

ALTER TABLE public.favorite_drivers ENABLE ROW LEVEL SECURITY;

-- Only permanent riders can use this table (authoritative DB-state check)
CREATE POLICY "favorites_permanent_riders_only"
  ON public.favorite_drivers FOR ALL
  USING (
    auth.uid() = rider_id
    AND EXISTS (
      SELECT 1
      FROM public.rider_accounts ra
      WHERE ra.id = auth.uid()
        AND ra.account_kind = 'permanent'
    )
  );
```

**Use a RESTRICTIVE policy** (not just permissive) to ensure anonymous users cannot bypass the check through a permissive OR-combination.

> **⚠️ Caution — JWT freshness:** If you also use `auth.jwt()->>'is_anonymous'` in app or policy checks, remember JWT claims are time-bound and can be stale until token refresh. Treat `public.rider_accounts.account_kind` as source of truth. After account upgrade, call `supabase.auth.refreshSession()` from the app.

### Step 2.3 — Enforce 10 Favorites Cap

```sql
CREATE OR REPLACE FUNCTION security.enforce_favorites_cap()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, security
AS $$
BEGIN
  IF (SELECT COUNT(*) FROM public.favorite_drivers WHERE rider_id = NEW.rider_id) >= 10 THEN
    RAISE EXCEPTION 'Maximum of 10 favorite drivers allowed.';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER enforce_favorites_cap
  BEFORE INSERT ON public.favorite_drivers
  FOR EACH ROW EXECUTE FUNCTION security.enforce_favorites_cap();
```

Business rules belong in the database — they cannot drift between client versions.

### Step 2.4 — Saved Places (Private, Permanent Riders Only)

```sql
-- Requires pg_jsonschema for validation
CREATE EXTENSION IF NOT EXISTS pg_jsonschema;

CREATE TABLE private.saved_places (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  rider_id        UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  label           TEXT NOT NULL CHECK (label IN ('home', 'work', 'gym', 'custom')),
  display_name    TEXT NOT NULL,
  address_json    JSONB NOT NULL,
  point           GEOGRAPHY(POINT, 4326) NOT NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (rider_id, label)
);
```

Expose saved places to the client only through a narrowly scoped RPC or `SECURITY INVOKER` view — never direct table access. Validate `address_json` with `pg_jsonschema` before insertion so malformed blobs never land in the database.

---

## Phase 3 — AI Consent Gate (Required for App Store)

This is the permanent fix for the Apple App Review issue. Build the enforcement into the backend itself, not just the UI.

### Step 3.1 — Consent Ledger

```sql
CREATE TABLE public.ai_consents (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  rider_id          UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  provider          TEXT NOT NULL,       -- e.g. 'openai', 'anthropic'
  disclosure_version TEXT NOT NULL,
  scope             TEXT NOT NULL,       -- e.g. 'dispatch_optimization'
  consented_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  revoked_at        TIMESTAMPTZ
);

ALTER TABLE public.ai_consents ENABLE ROW LEVEL SECURITY;

CREATE POLICY "ai_consents_own"
  ON public.ai_consents FOR ALL
  USING (auth.uid() = rider_id);
```

### Step 3.2 — AI Dispatch Audit Log (Private)

```sql
CREATE TABLE private.ai_dispatch_log (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  rider_id        UUID NOT NULL REFERENCES auth.users(id),
  provider        TEXT NOT NULL,
  provider_req_id TEXT,
  data_categories TEXT[] NOT NULL,    -- e.g. ARRAY['location','call_name']
  redacted        BOOLEAN NOT NULL DEFAULT FALSE,
  dispatched_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

This is your App Review evidence trail and GDPR audit trail. All AI provider secrets must live in **Edge Function environment variables or Supabase Vault** — never in the app bundle.

### Step 3.3 — Server-Side Consent Check

Before any Edge Function calls an external AI provider, it must check:

```typescript
// In your Edge Function
const { data: consent } = await supabaseAdmin
  .from('ai_consents')
  .select('id')
  .eq('rider_id', userId)
  .eq('provider', 'your_provider')
  .is('revoked_at', null)
  .single();

if (!consent) {
  return new Response(JSON.stringify({ error: 'AI consent required' }), { status: 403 });
}
```

---

## Phase 4 — Privacy & Data Retention

### Step 4.1 — Mark Contact Snapshots for Purge on Trip Completion

```sql
CREATE OR REPLACE FUNCTION security.on_ride_terminal_state()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private, security
AS $$
BEGIN
  IF NEW.ride_state IN ('completed', 'cancelled') AND OLD.ride_state NOT IN ('completed', 'cancelled') THEN
    UPDATE private.ride_contact_snapshots
    SET purge_after = NOW() + INTERVAL '30 days'  -- adjust to your retention policy
    WHERE ride_id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_ride_terminal_state
  AFTER UPDATE OF ride_state ON public.ride_requests
  FOR EACH ROW EXECUTE FUNCTION security.on_ride_terminal_state();
```

The 30-day window is a placeholder — your legal/business decision. But the **database must enforce whatever schedule you decide on**.

### Step 4.2 — Scheduled Cleanup Jobs (pg_cron)

```sql
-- Purge contact snapshots past their retention window
SELECT cron.schedule(
  'purge-expired-contact-snapshots',
  '0 3 * * *',   -- 3am daily
  $$DELETE FROM private.ride_contact_snapshots WHERE purge_after < NOW()$$
);

-- Purge stale anonymous users (Supabase does NOT auto-delete them)
-- Customize the interval based on your guest session policy
SELECT cron.schedule(
  'purge-stale-anonymous-users',
  '0 4 * * *',
  $$
    DELETE FROM auth.users
    WHERE id IN (
      SELECT id FROM public.rider_accounts
      WHERE account_kind = 'guest'
        AND last_seen_at < NOW() - INTERVAL '90 days'  -- your policy
    )
  $$
);
```

**Critical note:** Supabase anonymous sessions do not expire automatically. You must implement cleanup yourself.

> **⚠️ Caution — coordinate purge with product expectations:** before enabling anonymous-user deletion in production:
>
> - confirm expected guest persistence window with product,
> - ensure `last_seen_at` is actively maintained by app heartbeat,
> - guard against deleting users with active/non-terminal rides,
> - run a dry-run `SELECT` first to verify affected row counts.
>
> Suggested guarded delete:
>
> ```sql
> DELETE FROM auth.users
> WHERE id IN (
>   SELECT ra.id
>   FROM public.rider_accounts ra
>   WHERE ra.account_kind = 'guest'
>     AND ra.last_seen_at < NOW() - INTERVAL '90 days'
>     AND NOT EXISTS (
>       SELECT 1
>       FROM public.ride_requests rr
>       WHERE rr.rider_id = ra.id
>         AND rr.ride_state NOT IN ('completed', 'cancelled')
>     )
> );
> ```

### Step 4.3 — Retention Classes Reference

| Data category | Retention rule | Mechanism |
|---|---|---|
| Ride call name | Trip duration + 30 days (adjustable) | `purge_after` + pg_cron |
| Pickup/dropoff location | Trip + dispute window (e.g. 90 days) | Scheduled delete |
| Favorite drivers | Until user deletes or account erased | User-initiated + account delete cascade |
| Saved places | Until user deletes or account erased | User-initiated + account delete cascade |
| Stale guest accounts | 90 days of inactivity (adjustable) | pg_cron scheduled purge |
| AI consent records | Duration of account + legal hold | Manual / legal process |

---

## Phase 5 — Production Hardening

### Step 5.1 — Key and Access Discipline

- Mobile app uses **only the publishable key** (`sb_publishable_...`) against the HTTPS API.
- **Never** ship direct Postgres connection strings, service-role keys, or secret keys in the app bundle.
- Service-role keys stay in Edge Functions and backend services only — they bypass RLS entirely.
- Use **Network Restrictions** for any bastion hosts or CI runners with direct DB access.

### Step 5.2 — Prevent Accidentally Unprotected Tables

```sql
-- Auto-enable RLS on any new table created in the public schema
CREATE OR REPLACE FUNCTION security.auto_enable_rls()
RETURNS event_trigger
LANGUAGE plpgsql
AS $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN SELECT * FROM pg_event_trigger_ddl_commands() WHERE command_tag = 'CREATE TABLE'
  LOOP
    IF r.schema_name = 'public' THEN
      EXECUTE format(
        'ALTER TABLE %I.%I ENABLE ROW LEVEL SECURITY',
        r.schema_name,
        (SELECT relname FROM pg_class WHERE oid = r.objid)
      );
    END IF;
  END LOOP;
END;
$$;

CREATE EVENT TRIGGER auto_enable_rls_trigger
  ON ddl_command_end
  WHEN TAG IN ('CREATE TABLE')
  EXECUTE FUNCTION security.auto_enable_rls();
```

> **⚠️ Caution — event trigger payload field:** `object_identity` is a fully qualified identity string and can misbehave if treated as a plain identifier. Prefer using `objid -> pg_class.relname` as above. Test locally by creating a throwaway table and verifying `relrowsecurity = true`.

### Step 5.3 — Staff / Admin Access (Custom Claims + MFA)

- Add custom staff claims via a **Custom Access Token Hook** in Supabase Auth settings.
- Require `aal2` (MFA verified) for sensitive admin workflows: identity lookups, manual refunds, broad ride-history access.
- Use Supabase organization roles aggressively — most developers should not have Owner or Administrator access.

### Step 5.4 — Backup and Observability

- Enable **Point-in-Time Recovery (PITR)** if the app is revenue-critical.
- Enable **Auth Audit Logs** in Supabase Dashboard.
- Enable `pgaudit` extension for database-level query visibility.
- Enable **SSL enforcement** for all direct database connections.

### Step 5.5 — Storage (If You Use Profile Photos)

- Use **private Storage buckets** with owner-scoped policies.
- Service keys bypass Storage RLS — keep them server-side only.
- Remember: database backups do not restore deleted Storage objects. Only metadata is in the DB.

---

## Phase 6 — Testing and Deployment Discipline

- Manage all schema changes with **Supabase CLI migrations** (`supabase db diff`, `supabase migration new`). Treat the database as code.
- Write **pgTAP tests** for all RLS policies and critical functions before deploying.
- Run `plpgsql_check` to lint PL/pgSQL functions for errors.
- Run **Supabase Security Advisor** as part of every production deployment checklist.
- On mobile: no sensitive values in logs, use platform keychain/keystore for tokens, all traffic over TLS.

---

## Implementation Order Checklist

```
Phase 1 — Core (do before first real user)
  [ ] Supabase project in Frankfurt region
  [ ] Anonymous auth enabled with CAPTCHA
  [ ] Publishable/secret keys configured
  [ ] public.rider_accounts + RLS
  [ ] on_auth_user_created trigger
  [ ] public.ride_requests with PostGIS + RLS
  [ ] private.ride_contact_snapshots
  [ ] security.create_ride_request() RPC
  [ ] Auto-enable RLS event trigger

Phase 2 — Optional Features (before favorite/saved-place features ship)
  [ ] Email OTP upgrade flow in Flutter (linkIdentity)
  [ ] public.favorite_drivers + permanent-only RLS
  [ ] 10-favorites cap trigger
  [ ] private.saved_places + RPC accessor
  [ ] rider_accounts.account_kind upgrade on email verify

Phase 3 — AI Consent (before App Store resubmission)
  [ ] public.ai_consents + RLS
  [ ] private.ai_dispatch_log
  [ ] Edge Function consent check before any AI call
  [ ] Provider secrets in Vault / Edge Function env vars
  [ ] Disclosure modal in app with version tracking

Phase 4 — Retention
  [ ] on_ride_terminal_state trigger sets purge_after
  [ ] pg_cron jobs for contact snapshot purge
  [ ] pg_cron job for stale anonymous user purge
  [ ] Retention schedule documented and approved

Phase 5 — Hardening (before public launch)
  [ ] PITR enabled
  [ ] Auth Audit Logs enabled
  [ ] pgaudit enabled
  [ ] SSL enforcement on
  [ ] Network restrictions for direct DB access
  [ ] MFA enforced for staff/admin roles
  [ ] pgTAP RLS tests passing
  [ ] Security Advisor clean
```

---

## Resolved Decisions (v1)

These decisions are approved defaults for implementation unless explicitly changed later.

1. **Call name session scope** — Persist call name for the duration of an active trip (including app relaunch). Treat call name as trip-scoped data stored in `private.ride_contact_snapshots`. Allow local UX prefill on the same device, but do not treat that prefill as backend profile identity.
2. **Guest session scope** — Device-scoped anonymous identity by default. Keep one anonymous Supabase user per app install/session lifecycle, not per booking.
3. **Retention windows** — Use the following baseline:
   - ride contact snapshot (`call_name`, notes): 30 days after terminal ride state
   - trip location detail for operations/disputes: 90 days
   - stale guest cleanup: 180 days inactivity (with active-ride guard)
4. **AI providers** — Policy-facing provider is OpenAI (ChatGPT). If a gateway is used operationally, legal/privacy disclosures remain centered on OpenAI processing for rider AI support.
5. **Cross-border transfers** — Assume transfers may occur outside EEA for AI/support processing. Require DPA + SCCs + transfer assessment, and keep consent/privacy disclosure versioned and in sync.

---

## Open Decisions (Require Your Input Before Implementation)

These are policy decisions — the architecture supports any choice, but they must be made explicitly:

1. **Call name session scope** — Should the rider's entered call name survive an app relaunch within the same active trip, or reset on every app open?
2. **Guest session scope** — Is guest identity device-scoped (persists on same device across app relaunches) or trip-scoped (new anonymous user per booking)?
3. **Exact retention windows** — Confirm the business-approved durations for trip contact data, location data, and stale guest cleanup.
4. **AI providers** — Which third-party AI providers will you use? Each needs a proper DPA, the correct EU data transfer basis (adequacy or SCCs), and a separate consent disclosure version.
5. **Cross-border transfers** — If any AI provider or support processor is outside the EEA, document the transfer mechanism in your privacy policy and vendor contracts.
