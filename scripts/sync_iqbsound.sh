#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IQB_DIR="$ROOT_DIR/IQBSOUND"

RIDER_RIDER_DIR="$ROOT_DIR/apps/rider/assets/sounds/rider"
RIDER_SHARED_DIR="$ROOT_DIR/apps/rider/assets/sounds/shared"
DRIVER_DRIVER_DIR="$ROOT_DIR/apps/driver/assets/sounds/driver"
DRIVER_SHARED_DIR="$ROOT_DIR/apps/driver/assets/sounds/shared"

required_files=(
  "$IQB_DIR/driver/ride_request_incoming.mp3"
  "$IQB_DIR/rider/payment_success.mp3"
  "$IQB_DIR/shared/driver_found.mp3"
  "$IQB_DIR/shared/driver_arrived.mp3"
  "$IQB_DIR/shared/rider_cancelled.mp3"
  "$IQB_DIR/shared/driver_cancelled.mp3"
  "$IQB_DIR/shared/trip_complete.mp3"
  "$IQB_DIR/shared/general_notification.mp3"
)

for file in "${required_files[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "Missing required IQBSOUND file: $file" >&2
    exit 1
  fi
done

mkdir -p "$RIDER_RIDER_DIR" "$RIDER_SHARED_DIR" "$DRIVER_DRIVER_DIR" "$DRIVER_SHARED_DIR"

# Clear old generated sound files so IQBSOUND remains the single source.
rm -f "$RIDER_RIDER_DIR"/*.mp3 "$RIDER_SHARED_DIR"/*.mp3 "$DRIVER_DRIVER_DIR"/*.mp3 "$DRIVER_SHARED_DIR"/*.mp3

cp "$IQB_DIR/rider/payment_success.mp3" "$RIDER_RIDER_DIR/payment_success.mp3"

cp "$IQB_DIR/driver/ride_request_incoming.mp3" "$DRIVER_DRIVER_DIR/ride_request_incoming.mp3"

cp "$IQB_DIR/shared/driver_found.mp3" "$RIDER_SHARED_DIR/driver_found.mp3"
cp "$IQB_DIR/shared/driver_arrived.mp3" "$RIDER_SHARED_DIR/driver_arrived.mp3"
cp "$IQB_DIR/shared/rider_cancelled.mp3" "$RIDER_SHARED_DIR/rider_cancelled.mp3"
cp "$IQB_DIR/shared/driver_cancelled.mp3" "$RIDER_SHARED_DIR/driver_cancelled.mp3"
cp "$IQB_DIR/shared/trip_complete.mp3" "$RIDER_SHARED_DIR/trip_complete.mp3"
cp "$IQB_DIR/shared/general_notification.mp3" "$RIDER_SHARED_DIR/general_notification.mp3"

cp "$IQB_DIR/shared/driver_found.mp3" "$DRIVER_SHARED_DIR/driver_found.mp3"
cp "$IQB_DIR/shared/driver_arrived.mp3" "$DRIVER_SHARED_DIR/driver_arrived.mp3"
cp "$IQB_DIR/shared/rider_cancelled.mp3" "$DRIVER_SHARED_DIR/rider_cancelled.mp3"
cp "$IQB_DIR/shared/driver_cancelled.mp3" "$DRIVER_SHARED_DIR/driver_cancelled.mp3"
cp "$IQB_DIR/shared/trip_complete.mp3" "$DRIVER_SHARED_DIR/trip_complete.mp3"
cp "$IQB_DIR/shared/general_notification.mp3" "$DRIVER_SHARED_DIR/general_notification.mp3"

echo "IQBSOUND sync complete."
