# HeyCaby Driver

Flutter app for HeyCaby drivers. Uses Supabase Auth and the same backend as the rider app.

## Run

From this directory:

```bash
# Copy env from rider app or set your own
cp ../rider/.env .env   # then edit if needed

flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your_anon_key
```

Or use the same `SUPABASE_*` and `MAPBOX_ACCESS_TOKEN` as in the rider app (see repo README).

## What’s included

- **Auth:** Login and register (Supabase email/password). Splash redirects to `/login` or `/driver`.
- **Dashboard:** Driver home with status pill, today summary (trips, hours, earnings), and “Go online” entry.
- **Go online:** Change status (Go Online / Take a break / End shift) via `DriverApi.setStatus()`.
- **Tabs:** Home, Market, Radar, Community, Earnings (placeholders for the last four).
- **State:** `DriverStateNotifier` holds `DriverData` and `DriverAppState`; used for status and active ride.

## Next steps

See `DRIVER_APP_MAP.md` for the full screen list and build order. Next phases:

1. New ride request screen (incoming request, 30s countdown, Accept/Decline).
2. Active ride flow: navigating to pickup → at pickup → in progress → complete → rate rider.
3. Radar, earnings, onboarding, profile/settings.

## Shared packages

- `heycaby_api`: Supabase client, `DriverApi` (Bearer token for driver endpoints).
- `heycaby_ui`, `heycaby_map`, `heycaby_models`, `heycaby_utils`: theme, map, models, helpers.
