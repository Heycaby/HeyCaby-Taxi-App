# Domain incident runbook

Use [registry.yaml](./registry.yaml) before changing production.

1. Identify the domain from the affected state or command.
2. Confirm the authoritative table and command in the registry.
3. Correlate the ride, driver, user, or event ID with the listed audit evidence.
4. Check rejected command codes and Edge/Postgres logs before changing data.
5. Reproduce with the domain test or a transaction that always rolls back.
6. Fix the canonical command. Do not patch Rider/Driver presentation logic to hide backend disagreement.
7. Ship additive migrations and compatible wrappers first. Remove old paths only after minimum-version telemetry reaches zero.
8. Run `melos run guard:boundaries`, `melos run guard:authority`, targeted Flutter tests, SQL authority tests, and Supabase security advisors.
9. Record the incident, blast radius, migration/function version, monitoring signal, and rollback decision in the domain audit log.

Never restore anonymous blanket grants, accept caller-supplied identity for authority, or edit production Edge Functions only in the dashboard.
