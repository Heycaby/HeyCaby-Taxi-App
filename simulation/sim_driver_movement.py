"""
Brings sim drivers online and moves them along a simple route.
Upserts driver_locations every 5 seconds (matches app behaviour).
Run: python simulation/sim_driver_movement.py
"""
import asyncio
import math

from supabase import create_client

from simulation.config import SUPABASE_URL, SUPABASE_SERVICE_KEY, SIM_DRIVERS, ZONES

supabase = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)


def interpolate(start, end, steps):
    """Generate intermediate coordinates between two points."""
    return [
        (
            start[0] + (end[0] - start[0]) * i / steps,
            start[1] + (end[1] - start[1]) * i / steps,
        )
        for i in range(steps + 1)
    ]


def calculate_heading(lat1, lng1, lat2, lng2):
    """Calculate compass heading from point A to point B."""
    d_lng = lng2 - lng1
    x = math.cos(math.radians(lat2)) * math.sin(math.radians(d_lng))
    y = (
        math.cos(math.radians(lat1)) * math.sin(math.radians(lat2))
        - math.sin(math.radians(lat1))
        * math.cos(math.radians(lat2))
        * math.cos(math.radians(d_lng))
    )
    heading = (math.degrees(math.atan2(x, y)) + 360) % 360
    return int(heading)


async def move_driver(driver, route_points, steps_between=20):
    """Move a single driver along a series of zone waypoints."""
    driver_id = driver["id"]
    user_id = driver["id"]

    supabase.table("drivers").update(
        {"status": "available", "shift_start_at": "now()"}
    ).eq("id", driver_id).execute()
    print(f"✅ {driver['name']} is now ONLINE")

    for i in range(len(route_points) - 1):
        start = route_points[i]
        end = route_points[i + 1]
        hdg = calculate_heading(start[0], start[1], end[0], end[1])
        steps = interpolate(start, end, steps_between)

        for lat, lng in steps:
            supabase.table("driver_locations").upsert(
                {
                    "user_id": user_id,
                    "driver_id": driver_id,
                    "latitude": round(lat, 6),
                    "longitude": round(lng, 6),
                    "heading": hdg,
                    "speed_kmh": 35,
                    "updated_at": "now()",
                },
                on_conflict="user_id",
            ).execute()
            await asyncio.sleep(5)

    print(f"🏁 {driver['name']} completed route")


async def run_all_drivers():
    """Spread 5 sim drivers across Rotterdam zones."""
    tasks = []
    for i, driver in enumerate(SIM_DRIVERS):
        start_idx = i % len(ZONES)
        route = [
            (ZONES[start_idx]["lat"], ZONES[start_idx]["lng"]),
            (
                ZONES[(start_idx + 1) % len(ZONES)]["lat"],
                ZONES[(start_idx + 1) % len(ZONES)]["lng"],
            ),
            (
                ZONES[(start_idx + 2) % len(ZONES)]["lat"],
                ZONES[(start_idx + 2) % len(ZONES)]["lng"],
            ),
        ]
        tasks.append(move_driver(driver, route))
    await asyncio.gather(*tasks)


if __name__ == "__main__":
    asyncio.run(run_all_drivers())
