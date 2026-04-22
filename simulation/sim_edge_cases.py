"""
Tests edge cases and error handling scenarios.
Run: python simulation/sim_edge_cases.py
"""
import datetime
import random
import time
import uuid

from supabase import create_client

from simulation.config import (
    SUPABASE_URL,
    SUPABASE_SERVICE_KEY,
    SIM_RIDERS,
    SIM_DRIVERS,
    ZONES,
)

supabase = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)


def test_no_driver_available():
    """Scenario: Rider requests but all drivers are offline."""
    print("\n[TEST] No driver available scenario")
    for d in SIM_DRIVERS:
        supabase.table("drivers").update({"status": "offline"}).eq(
            "id", d["id"]
        ).execute()
    time.sleep(1)

    ride_id = str(uuid.uuid4())
    supabase.table("ride_requests").insert(
        {
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
        }
    ).execute()
    print(
        f"  ✅ Ride {ride_id[:8]} created — expect timeout/expired after 3 minutes"
    )
    return ride_id


def test_driver_cancels():
    """Scenario: Driver accepts then cancels."""
    print("\n[TEST] Driver cancels after accepting")
    ride_id = str(uuid.uuid4())

    supabase.table("ride_requests").insert(
        {
            "id": ride_id,
            "rider_token": SIM_RIDERS[1]["token"],
            "rider_identity_id": SIM_RIDERS[1]["identity_id"],
            "pickup_address": "Delfshaven, Rotterdam",
            "destination_address": "Centrum Zuid, Rotterdam",
            "pickup_coords": f"POINT({ZONES[3]['lng']} {ZONES[3]['lat']})",
            "destination_coords": f"POINT({ZONES[1]['lng']} {ZONES[1]['lat']})",
            "status": "pending",
            "booking_mode": "instant",
            "payment_method": "cash",
            "pickup_contact_name": SIM_RIDERS[1]["name"],
        }
    ).execute()

    time.sleep(2)

    supabase.table("drivers").update({"status": "available"}).eq(
        "id", SIM_DRIVERS[0]["id"]
    ).execute()
    supabase.table("ride_requests").update(
        {
            "status": "accepted",
            "driver_id": SIM_DRIVERS[0]["id"],
            "accepted_at": "now()",
        }
    ).eq("id", ride_id).execute()
    print(f"  ✅ Driver accepted ride {ride_id[:8]}")
    time.sleep(3)

    supabase.table("ride_requests").update(
        {
            "status": "cancelled",
            "cancelled_by": "driver",
            "cancellation_reason": "sim_test_cancel",
            "cancelled_at": "now()",
        }
    ).eq("id", ride_id).execute()
    supabase.table("drivers").update({"status": "offline"}).eq(
        "id", SIM_DRIVERS[0]["id"]
    ).execute()
    print("  ✅ Driver cancelled — rider app should show cancellation screen")
    return ride_id


def test_marketplace_bidding():
    """Scenario: Rider posts marketplace ride, driver bids."""
    print("\n[TEST] Marketplace bidding")
    ride_id = str(uuid.uuid4())

    supabase.table("ride_requests").insert(
        {
            "id": ride_id,
            "rider_token": SIM_RIDERS[2]["token"],
            "rider_identity_id": SIM_RIDERS[2]["identity_id"],
            "pickup_address": "Centrum Noord, Rotterdam",
            "destination_address": "Amsterdam Centraal",
            "pickup_coords": f"POINT({ZONES[0]['lng']} {ZONES[0]['lat']})",
            "destination_coords": "POINT(4.9003 52.3792)",
            "status": "pending",
            "booking_mode": "marketplace",
            "payment_method": "tikkie",
            "offered_fare": 45.00,
            "marketplace_offered_fare": 45.00,
            "estimated_distance_km": 75.0,
            "estimated_duration_min": 65,
            "pickup_contact_name": SIM_RIDERS[2]["name"],
        }
    ).execute()
    print(f"  ✅ Marketplace ride created {ride_id[:8]} — fare offered: €45.00")
    time.sleep(2)

    for i, driver in enumerate(SIM_DRIVERS[:3]):
        bid_amount = 43.00 - (i * 1.50)
        supabase.table("ride_bids").insert(
            {
                "ride_request_id": ride_id,
                "driver_id": driver["id"],
                "bid_amount": bid_amount,
                "eta_minutes": 8 + i,
                "message": f"Kan je ophalen in {8 + i} minuten.",
                "bid_number": i + 1,
                "status": "pending",
                "driver_snapshot": {"name": driver["name"], "rating": 4.8},
            }
        ).execute()
        print(f"  💰 {driver['name']} bid €{bid_amount}")
        time.sleep(1)

    return ride_id


def test_scheduled_ride():
    """Scenario: Rider books a ride 2 hours from now."""
    print("\n[TEST] Scheduled ride booking")
    scheduled_time = (
        datetime.datetime.utcnow() + datetime.timedelta(hours=2)
    ).isoformat() + "Z"
    ride_id = str(uuid.uuid4())

    supabase.table("ride_requests").insert(
        {
            "id": ride_id,
            "rider_token": SIM_RIDERS[3]["token"],
            "rider_identity_id": SIM_RIDERS[3]["identity_id"],
            "pickup_address": "Kop van Zuid, Rotterdam",
            "destination_address": "Centrum Noord, Rotterdam",
            "pickup_coords": f"POINT({ZONES[2]['lng']} {ZONES[2]['lat']})",
            "destination_coords": f"POINT({ZONES[0]['lng']} {ZONES[0]['lat']})",
            "status": "pending",
            "booking_mode": "scheduled",
            "payment_method": "cash",
            "scheduled_pickup_at": scheduled_time,
            "is_scheduled": True,
            "offered_fare": 12.50,
            "estimated_distance_km": 4.2,
            "estimated_duration_min": 10,
            "pickup_contact_name": SIM_RIDERS[3]["name"],
        }
    ).execute()
    print(f"  ✅ Scheduled ride {ride_id[:8]} for {scheduled_time}")
    return ride_id


def cleanup_sim_rides():
    """Remove all simulation ride data (safe — only touches sim tokens)."""
    print("\n[CLEANUP] Removing sim ride requests...")
    sim_tokens = [r["token"] for r in SIM_RIDERS]

    for token in sim_tokens:
        result = (
            supabase.table("ride_requests")
            .select("id")
            .eq("rider_token", token)
            .execute()
        )
        for ride in result.data:
            ride_id = ride["id"]
            supabase.table("ride_ratings").delete().eq(
                "ride_request_id", ride_id
            ).execute()
            supabase.table("ride_bids").delete().eq(
                "ride_request_id", ride_id
            ).execute()
            supabase.table("messages").delete().eq(
                "ride_request_id", ride_id
            ).execute()
        supabase.table("ride_requests").delete().eq(
            "rider_token", token
        ).execute()

    for d in SIM_DRIVERS:
        supabase.table("drivers").update(
            {
                "status": "offline",
                "shift_start_at": None,
                "shift_rides_today": 0,
                "shift_earnings_today": 0,
                "shift_total_online_minutes": 0,
            }
        ).eq("id", d["id"]).execute()

    print("  ✅ Cleanup complete")


if __name__ == "__main__":
    test_no_driver_available()
    time.sleep(5)
    test_driver_cancels()
    time.sleep(5)
    test_marketplace_bidding()
    time.sleep(5)
    test_scheduled_ride()
