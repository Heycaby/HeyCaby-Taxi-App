"""
Creates ride requests from sim riders pointing at real zone coordinates.
Posts directly to ride_requests via service role (bypasses RLS for simulation).
Run: python simulation/sim_ride_requests.py
"""
import random
import time
import uuid

from supabase import create_client

from simulation.config import SUPABASE_URL, SUPABASE_SERVICE_KEY, SIM_RIDERS, ZONES

supabase = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)

BOOKING_MODES = ["instant", "instant", "instant", "marketplace", "scheduled"]
PAYMENT_METHODS = ["cash", "pin", "tikkie"]


def create_ride_request(rider, pickup_zone, dest_zone):
    """Create one ride request for a sim rider."""
    mode = random.choice(BOOKING_MODES)

    pickup_lat = pickup_zone["lat"] + random.uniform(-0.003, 0.003)
    pickup_lng = pickup_zone["lng"] + random.uniform(-0.003, 0.003)
    dest_lat = dest_zone["lat"] + random.uniform(-0.003, 0.003)
    dest_lng = dest_zone["lng"] + random.uniform(-0.003, 0.003)

    dist_km = round(
        ((dest_lat - pickup_lat) ** 2 + (dest_lng - pickup_lng) ** 2) ** 0.5 * 111,
        1,
    )
    duration_min = round(dist_km / 0.5)
    fare = round(2.50 + dist_km * 2.20 + duration_min * 0.35, 2)

    payload = {
        "id": str(uuid.uuid4()),
        "rider_token": rider["token"],
        "rider_identity_id": rider["identity_id"],
        "pickup_address": f"{pickup_zone['name']}, Rotterdam",
        "destination_address": f"{dest_zone['name']}, Rotterdam",
        "pickup_coords": f"POINT({pickup_lng} {pickup_lat})",
        "destination_coords": f"POINT({dest_lng} {dest_lat})",
        "status": "pending",
        "booking_mode": mode,
        "payment_method": random.choice(PAYMENT_METHODS),
        "offered_fare": fare if mode == "marketplace" else None,
        "estimated_distance_km": dist_km,
        "estimated_duration_min": duration_min,
        "pickup_contact_name": rider["name"],
    }

    result = supabase.table("ride_requests").insert(payload).execute()
    ride_id = result.data[0]["id"]
    print(
        f"🚕 {rider['name']} → {pickup_zone['name']} to {dest_zone['name']}"
        f" [{mode}] ID:{ride_id[:8]}..."
    )
    return ride_id


def run_wave(num_requests=5):
    """Create a wave of ride requests from different riders."""
    created = []
    for i in range(num_requests):
        rider = SIM_RIDERS[i % len(SIM_RIDERS)]
        pickup = ZONES[i % len(ZONES)]
        dest = ZONES[(i + 2) % len(ZONES)]
        if pickup["name"] == dest["name"]:
            dest = ZONES[(i + 1) % len(ZONES)]
        ride_id = create_ride_request(rider, pickup, dest)
        created.append(ride_id)
        time.sleep(2)
    return created


if __name__ == "__main__":
    print("🏁 Starting ride request simulation...")
    ride_ids = run_wave(num_requests=5)
    print(f"\n✅ Created {len(ride_ids)} ride requests")
    print("Ride IDs:")
    for rid in ride_ids:
        print(f"  {rid}")
