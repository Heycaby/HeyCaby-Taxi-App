"""
Runs a complete ride lifecycle:
1. Rider creates request
2. Driver accepts
3. Driver moves to pickup (GPS updates)
4. Driver marks arrived
5. Driver starts ride, moves to destination
6. Driver marks complete
7. Rider rates driver

Run: python simulation/sim_full_lifecycle.py
"""
import asyncio
import math
import random
import uuid

from supabase import create_client

from simulation.config import (
    SUPABASE_URL,
    SUPABASE_SERVICE_KEY,
    SIM_DRIVERS,
    SIM_RIDERS,
    ZONES,
)

supabase = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)


def interpolate(start, end, steps=10):
    return [
        (
            start[0] + (end[0] - start[0]) * i / steps,
            start[1] + (end[1] - start[1]) * i / steps,
        )
        for i in range(steps + 1)
    ]


def heading(lat1, lng1, lat2, lng2):
    d = lng2 - lng1
    x = math.cos(math.radians(lat2)) * math.sin(math.radians(d))
    y = (
        math.cos(math.radians(lat1)) * math.sin(math.radians(lat2))
        - math.sin(math.radians(lat1))
        * math.cos(math.radians(lat2))
        * math.cos(math.radians(d))
    )
    return int((math.degrees(math.atan2(x, y)) + 360) % 360)


def upsert_location(driver_id, lat, lng, hdg):
    supabase.table("driver_locations").upsert(
        {
            "user_id": driver_id,
            "driver_id": driver_id,
            "latitude": round(lat, 6),
            "longitude": round(lng, 6),
            "heading": hdg,
            "speed_kmh": 35,
            "updated_at": "now()",
        },
        on_conflict="user_id",
    ).execute()


def set_ride_status(ride_id, status, extra=None):
    payload = {"status": status, "updated_at": "now()"}
    if extra:
        payload.update(extra)
    supabase.table("ride_requests").update(payload).eq("id", ride_id).execute()
    print(f"  📍 Ride status → {status}")


async def run_lifecycle(driver, rider, pickup_zone, dest_zone):
    driver_id = driver["id"]
    rider_token = rider["token"]

    print(f"\n{'='*60}")
    print(f"🚀 Lifecycle: {rider['name']} → {driver['name']}")
    print(f"   Route: {pickup_zone['name']} → {dest_zone['name']}")

    # 1. Driver goes online
    supabase.table("drivers").update({"status": "available"}).eq(
        "id", driver_id
    ).execute()
    upsert_location(
        driver_id, pickup_zone["lat"] + 0.01, pickup_zone["lng"] + 0.01, 180
    )
    print(f"  ✅ {driver['name']} online near {pickup_zone['name']}")

    # 2. Rider creates request
    dist_km = round(
        abs(dest_zone["lat"] - pickup_zone["lat"]) * 111
        + abs(dest_zone["lng"] - pickup_zone["lng"]) * 80,
        1,
    )
    fare = round(2.50 + dist_km * 2.20, 2)
    ride_id = str(uuid.uuid4())
    supabase.table("ride_requests").insert(
        {
            "id": ride_id,
            "rider_token": rider_token,
            "rider_identity_id": rider["identity_id"],
            "pickup_address": f"{pickup_zone['name']}, Rotterdam",
            "destination_address": f"{dest_zone['name']}, Rotterdam",
            "pickup_coords": f"POINT({pickup_zone['lng']} {pickup_zone['lat']})",
            "destination_coords": f"POINT({dest_zone['lng']} {dest_zone['lat']})",
            "status": "pending",
            "booking_mode": "instant",
            "payment_method": "cash",
            "estimated_distance_km": dist_km,
            "estimated_duration_min": round(dist_km / 0.5),
            "offered_fare": fare,
            "pickup_contact_name": rider["name"],
        }
    ).execute()
    print(f"  🚕 Ride request created: {ride_id[:8]}...")
    await asyncio.sleep(3)

    # 3. Driver accepts
    set_ride_status(
        ride_id, "accepted", {"driver_id": driver_id, "accepted_at": "now()"}
    )
    supabase.table("drivers").update({"status": "on_ride"}).eq(
        "id", driver_id
    ).execute()
    await asyncio.sleep(2)

    # 4. Driver moves to pickup
    driver_start = (pickup_zone["lat"] + 0.01, pickup_zone["lng"] + 0.01)
    pickup_pos = (pickup_zone["lat"], pickup_zone["lng"])
    print("  🚗 Driving to pickup...")
    for lat, lng in interpolate(driver_start, pickup_pos, steps=6):
        upsert_location(
            driver_id,
            lat,
            lng,
            heading(
                driver_start[0], driver_start[1], pickup_pos[0], pickup_pos[1]
            ),
        )
        await asyncio.sleep(4)

    # 5. Driver arrives at pickup
    set_ride_status(ride_id, "driver_arrived", {"driver_arrived_at": "now()"})
    await asyncio.sleep(3)

    # 6. Ride starts
    set_ride_status(ride_id, "in_progress", {"started_at": "now()"})
    print("  🛣️  Driving to destination...")
    dest_pos = (dest_zone["lat"], dest_zone["lng"])
    for lat, lng in interpolate(pickup_pos, dest_pos, steps=8):
        upsert_location(
            driver_id,
            lat,
            lng,
            heading(pickup_pos[0], pickup_pos[1], dest_pos[0], dest_pos[1]),
        )
        await asyncio.sleep(5)

    # 7. Ride completes
    set_ride_status(ride_id, "completed", {"completed_at": "now()"})
    supabase.table("drivers").update({"status": "available"}).eq(
        "id", driver_id
    ).execute()
    print("  ✅ Ride completed")
    await asyncio.sleep(2)

    # 8. Rider rates driver
    # ride_ratings.rider_comment has a DB constraint of max 100 chars.
    stars = random.choice([4, 4, 5, 5, 5])
    supabase.table("ride_ratings").upsert(
        {
            "ride_request_id": ride_id,
            "driver_id": driver_id,
            "rider_token": rider_token,
            "rider_rating_of_driver": stars,
            "rider_rated_at": "now()",
        },
        on_conflict="ride_request_id",
    ).execute()
    print(f"  ⭐ Rider rated driver: {stars}/5")

    print(f"  🏁 Lifecycle complete for ride {ride_id[:8]}")
    return ride_id


async def main():
    tasks = [
        run_lifecycle(SIM_DRIVERS[0], SIM_RIDERS[0], ZONES[0], ZONES[2]),
        run_lifecycle(SIM_DRIVERS[1], SIM_RIDERS[1], ZONES[1], ZONES[3]),
        run_lifecycle(SIM_DRIVERS[2], SIM_RIDERS[2], ZONES[2], ZONES[0]),
    ]
    results = await asyncio.gather(*tasks)
    print(f"\n✅ All lifecycles complete. Ride IDs: {[r[:8] for r in results]}")


if __name__ == "__main__":
    asyncio.run(main())
