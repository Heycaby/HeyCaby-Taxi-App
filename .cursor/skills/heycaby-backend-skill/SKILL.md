---
name: heycaby-backend-skill
description: Handles HeyCaby backend work end-to-end across Go API on AWS, Supabase, and Flutter clients. Use whenever a task touches backend endpoints, API routing, DB schema, RPCs, auth/session flow, or frontend-backend contract alignment.
---

# HeyCaby Back-end Skill

## Purpose

Use this skill for any backend-related change so work is done with full-system awareness, not one layer in isolation.

## Core Architecture Truths

Treat these as non-negotiable:

1. Backend business API is Go and hosted on AWS.
2. Supabase is used for database/auth/realtime/storage/RPC.
3. Frontend is Flutter (driver + rider).
4. Vercel is for marketing/public web pages, not the operational backend API.

## Deployment and Domain Guardrails

Use these concrete environment/domain rules:

- Marketing/public web origin: `https://heycaby.nl` and `https://www.heycaby.nl` (Vercel, website content).
- Supabase project (current prod): `fvrprxguoternoxnyhoj` (`https://fvrprxguoternoxnyhoj.supabase.co`).
- Operational Go API origin: AWS-hosted domain provided via `API_BASE_URL` dart-define.

Hard rules:

1. Never assume `heycaby.nl` / `www.heycaby.nl` is the backend API origin.
2. If API responses return HTML from these hosts, treat as routing/domain mismatch, not backend success.
3. Driver/Rider API clients must prefer environment-driven API base (`API_BASE_URL`) for backend calls.
4. Keep website/public links separate from API base links.

## When This Skill Must Trigger

Apply this skill when the task includes any of:

- Driver/rider API request failures (`401`, `404`, `405`, `307`, `308`, HTML response instead of JSON).
- Endpoint implementation or routing updates in Go backend.
- Supabase migrations, RPC creation/updates, RLS/policy/schema changes.
- Flutter API client contract updates (`heycaby_api`, request/response shape, fallback logic).
- Any bug where frontend behavior depends on backend status/data consistency.

## Working Rules

### 1) Diagnose Across All Layers

Always trace: `Flutter -> API host/routing -> Go handler/service/repository -> Supabase schema/RPC`.

Do not stop at first local fix.

### 2) Verify Correct API Origin

Before patching, confirm the app is hitting the intended AWS API origin (not marketing web host).

If a backend path returns HTML or web app shell:

- treat as wrong host/routing,
- avoid calling that a successful API response,
- patch client behavior and/or environment config.

### 3) Keep Contracts Aligned

When changing a backend payload or endpoint:

- update Go handler/service/repository together,
- update Flutter client models/methods,
- ensure error mapping is user-meaningful.

### 4) Use Supabase MCP for Live DB Changes

When DB/RPC changes are needed and MCP is available:

- inspect tool schema first,
- apply migration/RPC with MCP,
- report exactly what was applied.

### 5) Prefer Safe Fallbacks, Not Silent Failure

For temporary backend routing gaps:

- add explicit fallback (e.g. RPC path),
- detect invalid responses (e.g. `text/html` for API),
- surface clear actionable error messages.

## Backend Patch Checklist

For each backend task, execute this checklist:

- [ ] Confirm request host/origin is correct for AWS Go API.
- [ ] Confirm route existence and behavior (status + content type).
- [ ] Validate Go endpoint logic and expected response shape.
- [ ] Validate Supabase schema/RPC prerequisites.
- [ ] Align Flutter client request + parsing + fallback behavior.
- [ ] Run analyze/tests for touched files.
- [ ] Explain root cause and cross-layer fix in final note.

## Anti-Patterns To Avoid

- Fixing Flutter only while backend route is broken.
- Fixing Supabase only while API origin still points to web host.
- Treating redirect-to-HTML as acceptable API behavior.
- Shipping unverified assumptions about where a route is deployed.

