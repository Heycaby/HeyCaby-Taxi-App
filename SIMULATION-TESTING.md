# SIMULATION-TESTING.md
## HeyCaby — Full Simulation Testing Guide
### For the Cursor AI agent and manual testers

---

## WHAT IS ALREADY IN THE DATABASE

All simulation accounts are **live in production Supabase** (`fvrprxguoternoxnyhoj`). Do not recreate them.

### 5 Simulation Drivers

| Name | Driver ID | Email | Vehicle | Rate/km | Special |
|------|-----------|-------|---------|---------|---------|
| Sim Chauffeur 1 | `00000001-5100-0000-0000-000000000001` | sim1@sim.heycaby.test | Toyota Prius SIM-001 | €2.20 | Standard |
| Sim Chauffeur 2 | `00000002-5100-0000-0000-000000000002` | sim2@sim.heycaby.test | VW Passat SIM-002 | €2.50 | Pet friendly |
| Sim Chauffeur 3 | `00000003-5100-0000-0000-000000000003` | sim3@sim.heycaby.test | Tesla Model 3 SIM-003 | €2.80 | Electric |
| Sim Chauffeur 4 | `00000004-5100-0000-0000-000000000004` | sim4@sim.heycaby.test | Mercedes E-Class SIM-004 | €3.20 | Wheelchair |
| Sim Chauffeur 5 | `00000005-5100-0000-0000-000000000005` | sim5@sim.heycaby.test | Skoda Octavia SIM-005 | €2.00 | Budget |

All sim drivers: `status = offline`, `compliance_status = compliant`, `profile_status = verified`.
Auth password for all: `SimTest123!`

### 5 Simulation Riders

| Name | Identity ID | Token (x-rider-token header) | Payment |
|------|-------------|------------------------------|---------|
| Sim Rider 1 | `10000001-5100-0000-0000-000000000001` | `aaaaaaaa-0001-5100-0000-000000000001` | cash |
| Sim Rider 2 | `10000002-5100-0000-0000-000000000002` | `aaaaaaaa-0002-5100-0000-000000000002` | pin |
| Sim Rider 3 | `10000003-5100-0000-0000-000000000003` | `aaaaaaaa-0003-5100-0000-000000000003` | tikkie |
| Sim Rider 4 | `10000004-5100-0000-0000-000000000004` | `aaaaaaaa-0004-5100-0000-000000000004` | cash |
| Sim Rider 5 | `10000005-5100-0000-0000-000000000005` | `aaaaaaaa-0005-5100-0000-000000000005` | pin |

### Zone Coordinates for Simulation Movement

| Zone | City | Latitude | Longitude |
|------|------|----------|-----------|
| Centrum Noord | Rotterdam | 51.9255 | 4.4691 |
| Centrum Zuid | Rotterdam | 51.9172 | 4.4804 |
| Kop van Zuid | Rotterdam | 51.9058 | 4.4887 |
| Delfshaven | Rotterdam | 51.9234 | 4.4398 |
| Amsterdam Centraal | Amsterdam | 52.3792 | 4.9003 |
| De Pijp | Amsterdam | 52.3539 | 4.8929 |
| Jordaan | Amsterdam | 52.3747 | 4.8795 |
| Leidseplein | Amsterdam | 52.3625 | 4.8817 |

---

## PART 1 — PYTHON SIMULATION SCRIPTS

The agent writes and runs these scripts from the repo root.

### Setup

```bash
pip install supabase python-dotenv httpx asyncio
```

Set environment variables before running any script:
```bash
export SUPABASE_URL="<your-supabase-project-url>"          # from Supabase dashboard → Settings → API
export SUPABASE_SERVICE_ROLE_KEY="<your-service-role-key>"  # from Supabase dashboard → Settings → API
```

`simulation/config.py` reads these from the environment automatically. Sim account data and zone coordinates are embedded in the config file.

---

### Script 1 — Driver online + GPS movement

`simulation/sim_driver_movement.py`

```python
"""
Brings sim drivers online and moves them along a simple route.
Upserts driver_locations every 5 seconds (matches app behaviour).
Run: python simulation/sim_driver_movement.py
"""
import asyncio, math, time
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
    y = (math.cos(math.radians(lat1)) * math.sin(math.radians(lat2))
         - math.sin(math.radians(lat1)) * math.cos(math.radians(lat2))
         * math.cos(math.radians(d_lng)))
    heading = (math.degrees(math.atan2(x, y)) + 360) % 360
    return int(heading)

async def move_driver(driver, route_points, steps_between=20):
    """Move a single driver along a series of zone waypoints."""
    driver_id = driver["id"]
    user_id   = driver["id"]  # same UUID

    # Set driver online
    supabase.table("drivers").update({
        "status": "available",
        "shift_start_at": "now()"
    }).eq("id", driver_id).execute()
    print(f"✅ {driver['name']} is now ONLINE")

    for i in range(len(route_points) - 1):
        start = route_points[i]
        end   = route_points[i + 1]
        heading = calculate_heading(start[0], start[1], end[0], end[1])
        steps = interpolate(start, end, steps_between)

        for lat, lng in steps:
            # Upsert to driver_locations (PK = user_id)
            supabase.table("driver_locations").upsert({
                "user_id":    user_id,
                "driver_id":  driver_id,
                "latitude":   round(lat, 6),
                "longitude":  round(lng, 6),
                "heading":    heading,
                "speed_kmh":  35,
                "updated_at": "now()"
            }, on_conflict="user_id").execute()
            await asyncio.sleep(5)  # 5s interval matches Flutter app

    print(f"🏁 {driver['name']} completed route")

async def run_all_drivers():
    """Spread 5 sim drivers across Rotterdam zones."""
    tasks = []
    for i, driver in enumerate(SIM_DRIVERS):
        # Each driver gets a slightly different route through the zones
        start_idx = i % len(ZONES)
        route = [
            (ZONES[start_idx]["lat"],                       ZONES[start_idx]["lng"]),
            (ZONES[(start_idx + 1) % len(ZONES)]["lat"],   ZONES[(start_idx + 1) % len(ZONES)]["lng"]),
            (ZONES[(start_idx + 2) % len(ZONES)]["lat"],   ZONES[(start_idx + 2) % len(ZONES)]["lng"]),
        ]
        tasks.append(move_driver(driver, route))
    await asyncio.gather(*tasks)

if __name__ == "__main__":
    asyncio.run(run_all_drivers())
```

---

### Script 2 — Rider creates ride requests

`simulation/sim_ride_requests.py`

```python
"""
Creates ride requests from sim riders pointing at real zone coordinates.
Posts directly to ride_requests via service role (bypasses RLS for simulation).
Run: python simulation/sim_ride_requests.py
"""
import time, random, uuid
from supabase import create_client
from simulation.config import SUPABASE_URL, SUPABASE_SERVICE_KEY, SIM_RIDERS, ZONES

supabase = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)

BOOKING_MODES = ["instant", "instant", "instant", "marketplace", "scheduled"]
PAYMENT_METHODS = ["cash", "pin", "tikkie"]

def create_ride_request(rider, pickup_zone, dest_zone):
    """Create one ride request for a sim rider."""
    mode = random.choice(BOOKING_MODES)

    # Slight random offset within zone (±0.003 degrees ≈ ±300m)
    pickup_lat = pickup_zone["lat"] + random.uniform(-0.003, 0.003)
    pickup_lng = pickup_zone["lng"] + random.uniform(-0.003, 0.003)
    dest_lat   = dest_zone["lat"]   + random.uniform(-0.003, 0.003)
    dest_lng   = dest_zone["lng"]   + random.uniform(-0.003, 0.003)

    # Distance estimate (flat earth approximation — fine for simulation)
    dist_km = round(((dest_lat - pickup_lat)**2 + (dest_lng - pickup_lng)**2)**0.5 * 111, 1)
    duration_min = round(dist_km / 0.5)  # approx 30 km/h urban speed
    fare = round(2.50 + dist_km * 2.20 + duration_min * 0.35, 2)

    payload = {
        "id":                  str(uuid.uuid4()),
        "rider_token":         rider["token"],
        "rider_identity_id":   rider["identity_id"],
        "pickup_address":      f"{pickup_zone['name']}, Rotterdam",
        "destination_address": f"{dest_zone['name']}, Rotterdam",
        "pickup_coords":       f"POINT({pickup_lng} {pickup_lat})",   # lng FIRST
        "destination_coords":  f"POINT({dest_lng} {dest_lat})",
        "status":              "pending",
        "booking_mode":        mode,
        "payment_method":      random.choice(PAYMENT_METHODS),
        "offered_fare":        fare if mode == "marketplace" else None,
        "estimated_distance_km": dist_km,
        "estimated_duration_min": duration_min,
        "pickup_contact_name": rider["name"],
    }

    result = supabase.table("ride_requests").insert(payload).execute()
    ride_id = result.data[0]["id"]
    print(f"🚕 {rider['name']} → {pickup_zone['name']} to {dest_zone['name']} [{mode}] ID:{ride_id[:8]}...")
    return ride_id

def run_wave(num_requests=5):
    """Create a wave of ride requests from different riders."""
    created = []
    for i in range(num_requests):
        rider = SIM_RIDERS[i % len(SIM_RIDERS)]
        pickup = ZONES[i % len(ZONES)]
        dest   = ZONES[(i + 2) % len(ZONES)]  # always a different destination
        if pickup["name"] == dest["name"]:
            dest = ZONES[(i + 1) % len(ZONES)]
        ride_id = create_ride_request(rider, pickup, dest)
        created.append(ride_id)
        time.sleep(2)  # stagger requests 2s apart
    return created

if __name__ == "__main__":
    print("🏁 Starting ride request simulation...")
    ride_ids = run_wave(num_requests=5)
    print(f"\n✅ Created {len(ride_ids)} ride requests")
    print("Ride IDs:")
    for rid in ride_ids:
        print(f"  {rid}")
```

---

### Script 3 — Driver accepts rides (full lifecycle)

`simulation/sim_full_lifecycle.py`

```python
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
import asyncio, time, math, random, uuid
from supabase import create_client
from simulation.config import SUPABASE_URL, SUPABASE_SERVICE_KEY, SIM_DRIVERS, SIM_RIDERS, ZONES

supabase = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)

def interpolate(start, end, steps=10):
    return [(start[0] + (end[0]-start[0])*i/steps,
             start[1] + (end[1]-start[1])*i/steps) for i in range(steps+1)]

def heading(lat1, lng1, lat2, lng2):
    d = lng2 - lng1
    x = math.cos(math.radians(lat2)) * math.sin(math.radians(d))
    y = (math.cos(math.radians(lat1)) * math.sin(math.radians(lat2))
         - math.sin(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.cos(math.radians(d)))
    return int((math.degrees(math.atan2(x, y)) + 360) % 360)

def upsert_location(driver_id, lat, lng, hdg):
    supabase.table("driver_locations").upsert({
        "user_id": driver_id, "driver_id": driver_id,
        "latitude": round(lat,6), "longitude": round(lng,6),
        "heading": hdg, "speed_kmh": 35, "updated_at": "now()"
    }, on_conflict="user_id").execute()

def set_ride_status(ride_id, status, extra=None):
    payload = {"status": status, "updated_at": "now()"}
    if extra: payload.update(extra)
    supabase.table("ride_requests").update(payload).eq("id", ride_id).execute()
    print(f"  📍 Ride status → {status}")

async def run_lifecycle(driver, rider, pickup_zone, dest_zone):
    driver_id  = driver["id"]
    rider_token = rider["token"]
    ride_id    = None

    print(f"\n{'='*60}")
    print(f"🚀 Lifecycle: {rider['name']} → {driver['name']}")
    print(f"   Route: {pickup_zone['name']} → {dest_zone['name']}")

    # 1. Driver goes online
    supabase.table("drivers").update({"status": "available"}).eq("id", driver_id).execute()
    upsert_location(driver_id, pickup_zone["lat"] + 0.01, pickup_zone["lng"] + 0.01, 180)
    print(f"  ✅ {driver['name']} online near {pickup_zone['name']}")

    # 2. Rider creates request
    dist_km = round(abs(dest_zone["lat"]-pickup_zone["lat"]) * 111 + abs(dest_zone["lng"]-pickup_zone["lng"]) * 80, 1)
    fare = round(2.50 + dist_km * 2.20, 2)
    ride_id = str(uuid.uuid4())
    supabase.table("ride_requests").insert({
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
    }).execute()
    print(f"  🚕 Ride request created: {ride_id[:8]}...")
    await asyncio.sleep(3)

    # 3. Driver accepts
    set_ride_status(ride_id, "accepted", {
        "driver_id": driver_id, "accepted_at": "now()"
    })
    supabase.table("drivers").update({"status": "on_ride"}).eq("id", driver_id).execute()
    await asyncio.sleep(2)

    # 4. Driver moves to pickup (simulated GPS movement)
    driver_start = (pickup_zone["lat"] + 0.01, pickup_zone["lng"] + 0.01)
    pickup_pos   = (pickup_zone["lat"], pickup_zone["lng"])
    print(f"  🚗 Driving to pickup...")
    for lat, lng in interpolate(driver_start, pickup_pos, steps=6):
        upsert_location(driver_id, lat, lng, heading(driver_start[0],driver_start[1],pickup_pos[0],pickup_pos[1]))
        await asyncio.sleep(4)

    # 5. Driver arrives at pickup
    set_ride_status(ride_id, "driver_arrived", {"driver_arrived_at": "now()"})
    await asyncio.sleep(3)

    # 6. Ride starts
    set_ride_status(ride_id, "in_progress", {"started_at": "now()"})
    print(f"  🛣️  Driving to destination...")
    dest_pos = (dest_zone["lat"], dest_zone["lng"])
    for lat, lng in interpolate(pickup_pos, dest_pos, steps=8):
        upsert_location(driver_id, lat, lng, heading(pickup_pos[0],pickup_pos[1],dest_pos[0],dest_pos[1]))
        await asyncio.sleep(5)

    # 7. Ride completes
    set_ride_status(ride_id, "completed", {"completed_at": "now()"})
    supabase.table("drivers").update({"status": "available"}).eq("id", driver_id).execute()
    print(f"  ✅ Ride completed")
    await asyncio.sleep(2)

    # 8. Rider rates driver
    # ride_ratings.rider_comment has a DB constraint of max 100 chars.
    stars = random.choice([4, 4, 5, 5, 5])
    supabase.table("ride_ratings").upsert({
        "ride_request_id": ride_id,
        "driver_id": driver_id,
        "rider_token": rider_token,
        "rider_rating_of_driver": stars,
        "rider_rated_at": "now()"
    }, on_conflict="ride_request_id").execute()
    print(f"  ⭐ Rider rated driver: {stars}/5")

    print(f"  🏁 Lifecycle complete for ride {ride_id[:8]}")
    return ride_id

async def main():
    # Run 3 concurrent lifecycles
    tasks = [
        run_lifecycle(SIM_DRIVERS[0], SIM_RIDERS[0], ZONES[0], ZONES[2]),
        run_lifecycle(SIM_DRIVERS[1], SIM_RIDERS[1], ZONES[1], ZONES[3]),
        run_lifecycle(SIM_DRIVERS[2], SIM_RIDERS[2], ZONES[2], ZONES[0]),
    ]
    results = await asyncio.gather(*tasks)
    print(f"\n✅ All lifecycles complete. Ride IDs: {[r[:8] for r in results]}")

if __name__ == "__main__":
    asyncio.run(main())
```

---

### Script 4 — Edge case testing

`simulation/sim_edge_cases.py`

```python
"""
Tests edge cases and error handling scenarios.
Run: python simulation/sim_edge_cases.py
"""
import time, uuid
from supabase import create_client
from simulation.config import SUPABASE_URL, SUPABASE_SERVICE_KEY, SIM_RIDERS, SIM_DRIVERS, ZONES

supabase = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)

def test_no_driver_available():
    """Scenario: Rider requests but all drivers are offline."""
    print("\n[TEST] No driver available scenario")
    # Ensure all sim drivers are offline
    for d in SIM_DRIVERS:
        supabase.table("drivers").update({"status": "offline"}).eq("id", d["id"]).execute()
    time.sleep(1)

    ride_id = str(uuid.uuid4())
    supabase.table("ride_requests").insert({
        "id": ride_id,
        "rider_token": SIM_RIDERS[0]["token"],
        "rider_identity_id": SIM_RIDERS[0]["identity_id"],
        "pickup_address": "Centrum Noord, Rotterdam",
        "destination_address": "Kop van Zuid, Rotterdam",
        "pickup_coords": f"POINT({ZONES[0]['lng']} {ZONES[0]['lat']})",
        "destination_coords": f"POINT({ZONES[2]['lng']} {ZONES[2]['lat']})",
        "status": "pending",
        "booking_mode": "instant",
        "payment_method": "cash",
        "pickup_contact_name": SIM_RIDERS[0]["name"],
    }).execute()
    print(f"  ✅ Ride {ride_id[:8]} created — expect timeout/expired after 3 minutes")
    return ride_id

def test_driver_cancels():
    """Scenario: Driver accepts then cancels."""
    print("\n[TEST] Driver cancels after accepting")
    ride_id = str(uuid.uuid4())

    # Create ride
    supabase.table("ride_requests").insert({
        "id": ride_id,
        "rider_token": SIM_RIDERS[1]["token"],
        "rider_identity_id": SIM_RIDERS[1]["identity_id"],
        "pickup_address": "Delfshaven, Rotterdam",
        "destination_address": "Centrum Zuid, Rotterdam",
        "pickup_coords": f"POINT({ZONES[3]['lng']} {ZONES[3]['lat']})",
        "destination_coords": f"POINT({ZONES[1]['lng']} {ZONES[1]['lat']})",
        "status": "pending", "booking_mode": "instant",
        "payment_method": "cash",
        "pickup_contact_name": SIM_RIDERS[1]["name"],
    }).execute()

    time.sleep(2)

    # Driver accepts
    supabase.table("drivers").update({"status": "available"}).eq("id", SIM_DRIVERS[0]["id"]).execute()
    supabase.table("ride_requests").update({
        "status": "accepted", "driver_id": SIM_DRIVERS[0]["id"], "accepted_at": "now()"
    }).eq("id", ride_id).execute()
    print(f"  ✅ Driver accepted ride {ride_id[:8]}")
    time.sleep(3)

    # Driver cancels
    supabase.table("ride_requests").update({
        "status": "cancelled", "cancelled_by": "driver",
        "cancellation_reason": "sim_test_cancel", "cancelled_at": "now()"
    }).eq("id", ride_id).execute()
    supabase.table("drivers").update({"status": "offline"}).eq("id", SIM_DRIVERS[0]["id"]).execute()
    print(f"  ✅ Driver cancelled — rider app should show cancellation screen")
    return ride_id

def test_marketplace_bidding():
    """Scenario: Rider posts marketplace ride, driver bids."""
    print("\n[TEST] Marketplace bidding")
    ride_id = str(uuid.uuid4())

    supabase.table("ride_requests").insert({
        "id": ride_id,
        "rider_token": SIM_RIDERS[2]["token"],
        "rider_identity_id": SIM_RIDERS[2]["identity_id"],
        "pickup_address": "Centrum Noord, Rotterdam",
        "destination_address": "Amsterdam Centraal",
        "pickup_coords": f"POINT({ZONES[0]['lng']} {ZONES[0]['lat']})",
        "destination_coords": "POINT(4.9003 52.3792)",
        "status": "pending", "booking_mode": "marketplace",
        "payment_method": "tikkie",
        "offered_fare": 45.00,
        "marketplace_offered_fare": 45.00,
        "estimated_distance_km": 75.0,
        "estimated_duration_min": 65,
        "pickup_contact_name": SIM_RIDERS[2]["name"],
    }).execute()
    print(f"  ✅ Marketplace ride created {ride_id[:8]} — fare offered: €45.00")
    time.sleep(2)

    # Sim drivers place bids
    for i, driver in enumerate(SIM_DRIVERS[:3]):
        bid_amount = 43.00 - (i * 1.50)  # competitive bids descending
        supabase.table("ride_bids").insert({
            "ride_request_id": ride_id,
            "driver_id": driver["id"],
            "bid_amount": bid_amount,
            "eta_minutes": 8 + i,
            "message": f"Kan je ophalen in {8+i} minuten.",
            "bid_number": i + 1,
            "status": "pending",
            "driver_snapshot": {"name": driver["name"], "rating": 4.8}
        }).execute()
        print(f"  💰 {driver['name']} bid €{bid_amount}")
        time.sleep(1)

    return ride_id

def test_scheduled_ride():
    """Scenario: Rider books a ride 2 hours from now."""
    import datetime
    print("\n[TEST] Scheduled ride booking")
    scheduled_time = (datetime.datetime.utcnow() + datetime.timedelta(hours=2)).isoformat() + "Z"
    ride_id = str(uuid.uuid4())

    supabase.table("ride_requests").insert({
        "id": ride_id,
        "rider_token": SIM_RIDERS[3]["token"],
        "rider_identity_id": SIM_RIDERS[3]["identity_id"],
        "pickup_address": "Kop van Zuid, Rotterdam",
        "destination_address": "Centrum Noord, Rotterdam",
        "pickup_coords": f"POINT({ZONES[2]['lng']} {ZONES[2]['lat']})",
        "destination_coords": f"POINT({ZONES[0]['lng']} {ZONES[0]['lat']})",
        "status": "pending", "booking_mode": "scheduled",
        "payment_method": "cash",
        "scheduled_pickup_at": scheduled_time,
        "is_scheduled": True,
        "offered_fare": 12.50,
        "estimated_distance_km": 4.2,
        "estimated_duration_min": 10,
        "pickup_contact_name": SIM_RIDERS[3]["name"],
    }).execute()
    print(f"  ✅ Scheduled ride {ride_id[:8]} for {scheduled_time}")
    return ride_id

def cleanup_sim_rides():
    """Remove all simulation ride data (safe — only touches sim tokens)."""
    print("\n[CLEANUP] Removing sim ride requests...")
    sim_tokens = [r["token"] for r in SIM_RIDERS]

    for token in sim_tokens:
        result = supabase.table("ride_requests").select("id").eq("rider_token", token).execute()
        for ride in result.data:
            ride_id = ride["id"]
            supabase.table("ride_ratings").delete().eq("ride_request_id", ride_id).execute()
            supabase.table("ride_bids").delete().eq("ride_request_id", ride_id).execute()
            supabase.table("messages").delete().eq("ride_request_id", ride_id).execute()
        supabase.table("ride_requests").delete().eq("rider_token", token).execute()

    # Reset drivers to offline
    for d in SIM_DRIVERS:
        supabase.table("drivers").update({
            "status": "offline",
            "shift_start_at": None,
            "shift_rides_today": 0,
            "shift_earnings_today": 0,
            "shift_total_online_minutes": 0
        }).eq("id", d["id"]).execute()

    print("  ✅ Cleanup complete")

if __name__ == "__main__":
    test_no_driver_available()
    time.sleep(5)
    test_driver_cancels()
    time.sleep(5)
    test_marketplace_bidding()
    time.sleep(5)
    test_scheduled_ride()
```

---

## PART 2 — TEST SCENARIOS AND PASS/FAIL CRITERIA

Run these in order. Each scenario has a SQL verification query.

### Scenario 1 — Basic instant booking (happy path)

**Run:** `python simulation/sim_full_lifecycle.py`

**Pass criteria:**
```sql
-- Should find 3 completed rides with ratings
SELECT r.status, r.booking_mode, r.driver_id,
       rt.rider_rating_of_driver
FROM ride_requests r
LEFT JOIN ride_ratings rt ON rt.ride_request_id = r.id
WHERE r.rider_token LIKE 'aaaaaaaa%'
AND r.status = 'completed'
ORDER BY r.completed_at DESC
LIMIT 5;
```
- ✅ Pass: 3 rows with `status = 'completed'` and `rider_rating_of_driver` not null
- ❌ Fail: status stuck at `pending` or `accepted`, or ratings missing

---

### Scenario 2 — Realtime latency check

**What to measure:** Time from `status` column update to Realtime event received in Flutter.

**Target latencies:**
| Event | Target |
|-------|--------|
| Rider creates ride → driver app notification | < 5 seconds |
| Driver accepts → rider sees driver on map | < 3 seconds |
| Driver location update → rider map moves | < 3 seconds |
| Driver arrives → rider notification | < 2 seconds |
| Ride complete → rider complete screen | < 3 seconds |

**Measure with:**
```sql
-- Check update timestamps vs created_at to see processing lag
SELECT status, created_at, updated_at,
       EXTRACT(EPOCH FROM (updated_at - created_at)) AS lag_seconds
FROM ride_requests
WHERE rider_token LIKE 'aaaaaaaa%'
ORDER BY updated_at DESC LIMIT 10;
```

---

### Scenario 3 — No driver available (timeout)

**Run:** `python simulation/sim_edge_cases.py` (first test only)

**Pass criteria:**
```sql
-- Ride should expire within 3 minutes
SELECT id, status, created_at, expires_at
FROM ride_requests
WHERE rider_token = 'aaaaaaaa-0001-5100-0000-000000000001'
ORDER BY created_at DESC LIMIT 1;
```
- ✅ Pass: `status = 'expired'` within 3 minutes
- ❌ Fail: stuck at `pending` forever, or app crashes

---

### Scenario 4 — Driver cancels after accepting

**Pass criteria:**
```sql
SELECT status, cancelled_by, cancellation_reason, cancelled_at
FROM ride_requests
WHERE cancelled_by = 'driver'
AND rider_token = 'aaaaaaaa-0002-5100-0000-000000000002'
ORDER BY cancelled_at DESC LIMIT 1;
```
- ✅ Pass: `status = 'cancelled'`, `cancelled_by = 'driver'`
- ❌ Fail: rider app doesn't update, or no cancellation screen shown

---

### Scenario 5 — Marketplace bids appear in real time

**Pass criteria:**
```sql
SELECT rb.bid_amount, rb.eta_minutes, rb.status,
       d.full_name
FROM ride_bids rb
JOIN drivers d ON d.id = rb.driver_id
WHERE rb.ride_request_id = (
  SELECT id FROM ride_requests
  WHERE booking_mode = 'marketplace'
  AND rider_token = 'aaaaaaaa-0003-5100-0000-000000000003'
  ORDER BY created_at DESC LIMIT 1
)
ORDER BY rb.bid_amount ASC;
```
- ✅ Pass: 3 bids visible, different amounts, rider app shows bid cards
- ❌ Fail: bids not appearing, or real-time not firing

---

### Scenario 6 — Scheduled ride appears in driver's list

**Pass criteria:**
```sql
-- Verify scheduled ride appears in scheduled_rides_available view
SELECT id, pickup_address, destination_address,
       scheduled_pickup_at, status
FROM scheduled_rides_available
WHERE pickup_address LIKE '%Rotterdam%'
ORDER BY scheduled_pickup_at;
```
- ✅ Pass: ride appears in view with correct pickup time
- ❌ Fail: missing from view (check `is_scheduled = true` and `expires_at`)

---

### Scenario 7 — GPS movement updates on rider map

**Check driver_locations is updating:**
```sql
SELECT user_id, latitude, longitude, heading, updated_at
FROM driver_locations
WHERE driver_id IN (
  '00000001-5100-0000-0000-000000000001',
  '00000002-5100-0000-0000-000000000002'
)
ORDER BY updated_at DESC;
```
- ✅ Pass: `updated_at` is within the last 30 seconds during simulation
- ❌ Fail: stale timestamp, driver not moving on rider map

---

### Scenario 8 — Zone demand live view updates

**Pass criteria:**
```sql
SELECT zone_id, name_display, waiting_passengers, demand_level
FROM zone_demand_live
WHERE waiting_passengers > 0
ORDER BY waiting_passengers DESC;
```
- ✅ Pass: zones with sim riders' pending rides show `waiting_passengers > 0`
- ❌ Fail: view always returns 0 (check ride `status = 'pending'` and `expires_at`)

---

## PART 3 — MONITORING QUERIES

Run these in Supabase SQL editor while the simulation is running.

```sql
-- Live dashboard — current state of all sim rides
SELECT
  r.id,
  r.status,
  r.booking_mode,
  r.rider_token,
  d.full_name AS driver_name,
  r.pickup_address,
  r.destination_address,
  r.created_at,
  r.updated_at
FROM ride_requests r
LEFT JOIN drivers d ON d.id = r.driver_id
WHERE r.rider_token LIKE 'aaaaaaaa%'
ORDER BY r.updated_at DESC;

-- Driver location positions right now
SELECT d.full_name, dl.latitude, dl.longitude, dl.heading, dl.updated_at
FROM driver_locations dl
JOIN drivers d ON d.id = dl.driver_id
WHERE d.email LIKE '%@sim.heycaby.test'
ORDER BY dl.updated_at DESC;

-- Driver status summary
SELECT full_name, status, shift_rides_today, shift_earnings_today
FROM drivers WHERE email LIKE '%@sim.heycaby.test';

-- All ratings submitted by sim riders
SELECT rr.id, rr.rider_rating_of_driver, rr.rider_comment, rr.rider_rated_at
FROM ride_ratings rr
JOIN ride_requests r ON r.id = rr.ride_request_id
WHERE r.rider_token LIKE 'aaaaaaaa%';
```

---

## PART 4 — CLEANUP

After testing, run the cleanup function to remove all simulation ride data while keeping the accounts:

```python
from simulation.sim_edge_cases import cleanup_sim_rides
cleanup_sim_rides()
```

Or run directly in SQL:
```sql
-- Remove sim ride data only (safe — uses rider_token filter)
DELETE FROM ride_ratings
WHERE ride_request_id IN (
  SELECT id FROM ride_requests WHERE rider_token LIKE 'aaaaaaaa%'
);

DELETE FROM ride_bids
WHERE ride_request_id IN (
  SELECT id FROM ride_requests WHERE rider_token LIKE 'aaaaaaaa%'
);

DELETE FROM messages
WHERE ride_request_id IN (
  SELECT id FROM ride_requests WHERE rider_token LIKE 'aaaaaaaa%'
);

DELETE FROM ride_requests WHERE rider_token LIKE 'aaaaaaaa%';

-- Reset sim drivers to offline
UPDATE drivers SET
  status = 'offline',
  shift_start_at = NULL,
  shift_rides_today = 0,
  shift_earnings_today = 0,
  shift_total_online_minutes = 0
WHERE email LIKE '%@sim.heycaby.test';
```

---

## PART 5 — FINAL REPORT FORMAT

After running all scenarios, output this table:

| Scenario | Expected | Actual | Pass/Fail | Notes |
|----------|---------|--------|-----------|-------|
| 1. Happy path lifecycle | 3 completed rides + ratings | | | |
| 2. Realtime latency | All events < 5s | | | |
| 3. No driver timeout | status = expired in 3 min | | | |
| 4. Driver cancel | status = cancelled, rider screen updates | | | |
| 5. Marketplace bids | 3 bids visible in real time | | | |
| 6. Scheduled ride in view | Appears in scheduled_rides_available | | | |
| 7. GPS movement | driver_locations updated every 5s | | | |
| 8. Zone demand | waiting_passengers > 0 for active zones | | | |
