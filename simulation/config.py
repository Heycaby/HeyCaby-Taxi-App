import os

SUPABASE_URL = os.environ["SUPABASE_URL"]
SUPABASE_SERVICE_KEY = os.environ["SUPABASE_SERVICE_ROLE_KEY"]
NEXT_API_BASE = os.environ.get("NEXT_API_BASE", "https://heycaby.nl")

# Sim driver IDs and their Supabase auth UUIDs (same value)
SIM_DRIVERS = [
    {"id": "00000001-5100-0000-0000-000000000001", "name": "Sim Chauffeur 1", "email": "sim1@sim.heycaby.test"},
    {"id": "00000002-5100-0000-0000-000000000002", "name": "Sim Chauffeur 2", "email": "sim2@sim.heycaby.test"},
    {"id": "00000003-5100-0000-0000-000000000003", "name": "Sim Chauffeur 3", "email": "sim3@sim.heycaby.test"},
    {"id": "00000004-5100-0000-0000-000000000004", "name": "Sim Chauffeur 4", "email": "sim4@sim.heycaby.test"},
    {"id": "00000005-5100-0000-0000-000000000005", "name": "Sim Chauffeur 5", "email": "sim5@sim.heycaby.test"},
]

# Sim rider tokens (x-rider-token header value)
SIM_RIDERS = [
    {"identity_id": "10000001-5100-0000-0000-000000000001", "token": "aaaaaaaa-0001-5100-0000-000000000001", "name": "Sim Rider 1"},
    {"identity_id": "10000002-5100-0000-0000-000000000002", "token": "aaaaaaaa-0002-5100-0000-000000000002", "name": "Sim Rider 2"},
    {"identity_id": "10000003-5100-0000-0000-000000000003", "token": "aaaaaaaa-0003-5100-0000-000000000003", "name": "Sim Rider 3"},
    {"identity_id": "10000004-5100-0000-0000-000000000004", "token": "aaaaaaaa-0004-5100-0000-000000000004", "name": "Sim Rider 4"},
    {"identity_id": "10000005-5100-0000-0000-000000000005", "token": "aaaaaaaa-0005-5100-0000-000000000005", "name": "Sim Rider 5"},
]

# Rotterdam zones for simulation
ZONES = [
    {"name": "Centrum Noord",   "lat": 51.9255, "lng": 4.4691},
    {"name": "Centrum Zuid",    "lat": 51.9172, "lng": 4.4804},
    {"name": "Kop van Zuid",    "lat": 51.9058, "lng": 4.4887},
    {"name": "Delfshaven",      "lat": 51.9234, "lng": 4.4398},
]
