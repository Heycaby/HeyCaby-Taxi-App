# Migration 040 — Ratings (Flutter + Supabase)

## Verified on project `fvrprxguoternoxnyhoj` (HeyCaby production Supabase)

- **`ride_ratings`** already has: `punctuality`, `cleanliness`, `attitude`, `driving_safety`, `communication`, flags, `admin_excluded`, etc.
- **`drivers`** does **not** store per-category averages or `trust_score` as columns used by the app.
- **`driver_trust_scores`** (table/view) + **`driver_my_rating`** (view, `WHERE driver_id IN (SELECT id FROM drivers WHERE user_id = auth.uid())`) expose:
  - `public_stars`, `trust_score`, sub-averages, `flag_review_needed`, `flag_review_reason`, badges, `in_protected_window`, etc.

## Rider app

- `apps/rider/lib/screens/rating_screen.dart` updates `ride_ratings` by `ride_request_id` with overall + five sub-scores (see code).

## Driver app

- **`getDriverMyRating()`** reads **`driver_my_rating`** only — no duplicate rating logic, no extra `drivers` columns required.
- **`driverMyRatingProvider`** powers **Driver score** screen: public stars, trust score (0–100), breakdown, new-driver shield, review flag banner, badges.
- **`getShiftStats`** remains for shift/acceptance/`rating` on `drivers` only; sub-averages were removed from that select to avoid a failing query.

## Do not

- Create a second `drivers`-like table or duplicate `ride_ratings`.
- Drop `driver_trust_scores` / `driver_my_rating` without a migration plan.

## If `driver_my_rating` returns no row

- New drivers may have no row yet → UI falls back to `drivers.rating` for the headline star only.
