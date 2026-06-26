# HeyCaby Notification Matrix (Program 3C)

Permanent contract for sound, haptic, deep-link, and audit behavior across rider and driver apps.

Implementation:
- Rider: `apps/rider/lib/services/rider_notification_router.dart`
- Driver: `apps/driver/lib/services/driver_notification_router.dart`
- Driver pings: `packages/heycaby_api/lib/src/driver_ping_types.dart` + `driver-agent` edge function
- Android channels (rider): `apps/rider/lib/services/rider_notification_channels.dart`

## Ride lifecycle events

| Event | Category (examples) | Sound | Haptic | Opens | Audit event |
| ----- | ------------------- | ----- | ------ | ----- | ------------- |
| Ride offer (driver) | `incoming_ride` | Loud (`ride_request`) | Heavy | `/driver/ride/new/:id` | `ride.offered` |
| Driver accepted (rider) | `driver_found`, `driver_assigned` | `driver_found.mp3` | Medium | `/active` | `ride.accepted` |
| Driver on my way | `driver_ping_on_my_way` | `driver_found.mp3` | Double (standard) | `/active` | `driver.ping_on_my_way` |
| Driver outside | `driver_ping_outside` | `driver_arrived.mp3` | Heavy ×2 | `/active` | `driver.ping_outside` |
| Driver arrived | `driver_ping_arrived` | `driver_arrived.mp3` | Heavy ×2 | `/active` | `driver.ping_arrived` |
| Running late / traffic | `driver_ping_running_late`, `driver_ping_traffic_delay` | `driver_found.mp3` | Standard | `/active` | `driver.ping_*` |
| Chat message | `chat` | `general_notification.mp3` | Light | Chat thread | — |
| Ride cancelled | `ride_phase`, `*_cancelled` | `driver_cancelled.mp3` / `rider_cancelled.mp3` | Triple (error) | Home / status | `ride.cancelled` |
| Trip started | `in_progress` | `driver_found.mp3` | Medium | `/active` | `ride.started` |
| Trip completed | `trip_complete` | `trip_complete.mp3` | Light | Receipt | `ride.completed` |
| Payment / billing | `payment_*` | `payment_success.mp3` | Light | Wallet / account | — |

## Ping delivery lifecycle

Each manual ping writes immutable audit rows:

```
driver.ping_{kind}           metadata.delivery_state = sent
driver.ping_{kind}.delivered metadata.delivery_state = delivered  (after FCM push_sent_at)
driver.ping_{kind}.opened    metadata.delivery_state = opened     (rider foreground alert, best-effort)
```

Future: `expired` when push token missing after TTL.

Cooldown: **30 seconds** per `(ride_id, ping_kind)` for **manual** pings — client + server (`ride_audit_log`).

Automatic pings (`metadata.automatic = true`) skip cooldown but dedupe **once per ride + kind** on the server.

## Automatic pings (driver)

| Trigger | Ping | Dedupe |
| ------- | ---- | ------ |
| Accept ride | On my way | Once per ride |
| ≤ 150 m from pickup (GPS) | Outside | Once per ride |
| Mark arrived | Arrived | Once per ride |

Client: `DriverAutomaticPingService` + `DriverAutomaticPingListener` (shell). Server: `driver-agent` with `automatic: true`.

## Platform health (`fn_driver_platform_health`)

`communication` block (support / runtime):

- `chat_available`, `push_available`, `active_ride_id`
- `last_ping_event`, `last_ping_at`, `last_ping_automatic`
- `last_ping_delivered`, `last_ping_delivered_at`
- `cooldown_remaining_sec` (manual pings only)

Rider opened pings: `fn_rider_ping_mark_opened(ride_id, ping_kind)` → `driver.ping_{kind}.opened`.

## Ping history (support)

`fn_ride_ping_timeline(ride_id)` returns audit rows for `driver.ping_*` events.

Driver UI: expandable **Ping geschiedenis** in Communication Center (`DriverPingHistorySection`).

## Communication Center (driver)

Context-aware quick actions (no phone numbers):

| Phase | Distance | Quick pings |
| ----- | -------- | ----------- |
| En route | > 500 m | On my way, Running late |
| En route | ≤ 500 m | Outside, Arrived, Can't find you |
| At pickup | — | Outside, Arrived, Can't find you |
| In progress | — | Running late, Traffic |
| After trip | — | Hidden |

Smart suggestions:
- **30 s** en route → suggest "On my way"
- **≤ 150 m** from pickup → suggest "I'm outside"

## Android notification channels

| Channel ID | Use |
| ---------- | --- |
| `heycaby_ping_urgent` | Outside, arrived, can't find |
| `heycaby_ping_standard` | On my way, delays |
| `heycaby_ping_soft` | Thanks, light updates |
| `heycaby_ride_events` | Accept, cancel, trip |
| `heycaby_chat` | Chat messages |

FCM sets `android.notification.channel_id` from ping dispatch (`ping_helpers.ts`).

## Future (not V1)

- iOS custom sounds per channel
- Driver Android notification channels (local plugin)
