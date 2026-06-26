# Rider Sound Pack Guide

Put all Rider app sound files in this folder tree:

- `assets/sounds/rider/`
- `assets/sounds/driver/` (kept for compatibility with existing pubspec)
- `assets/sounds/shared/`

Use these rules for every file:

- Format: `mp3`
- Sample rate: `44.1kHz`
- Bitrate: `192 kbps` or `256 kbps`
- Channels: `stereo`
- Naming: lowercase + underscores only

## Final Sound Set (8 files)

Drop these into `assets/sounds/rider/`:

- `payment_success.mp3` (rider payment success)

Drop these into `assets/sounds/driver/`:

- `ride_request_incoming.mp3` (incoming request loop)

Drop these into `assets/sounds/shared/`:

- `driver_found.mp3`
- `driver_arrived.mp3`
- `rider_cancelled.mp3`
- `driver_cancelled.mp3`
- `trip_complete.mp3`
- `general_notification.mp3`

