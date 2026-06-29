import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter, Rate } from 'k6/metrics';
import { SharedArray } from 'k6/data';

const SUPABASE_URL = (__ENV.SUPABASE_URL || '').replace(/\/$/, '');
const SUPABASE_ANON_KEY = __ENV.SUPABASE_ANON_KEY || '';
const MANIFEST_PATH = __ENV.DRIVER_MANIFEST || 'build/load/k6_scale_drivers.json';
const DRIVER_COUNT = Number.parseInt(__ENV.DRIVERS || '5000', 10);
const UPDATE_INTERVAL_SEC = Number.parseFloat(__ENV.UPDATE_INTERVAL_SEC || '5');
const DURATION = __ENV.DURATION || '5m';
const RAMP_UP = __ENV.RAMP_UP || '30s';
const TIMEOUT = __ENV.HTTP_TIMEOUT || '10s';
const CENTER_RADIUS_KM = Number.parseFloat(__ENV.CENTER_RADIUS_KM || '0.15');

if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
  throw new Error('SUPABASE_URL and SUPABASE_ANON_KEY are required');
}

const manifest = new SharedArray('heycaby-drivers', () => {
  const raw = JSON.parse(open(MANIFEST_PATH));
  const rows = raw.drivers || raw;
  if (!Array.isArray(rows) || rows.length === 0) {
    throw new Error(`No drivers found in ${MANIFEST_PATH}`);
  }
  return rows;
});

if (manifest.length < DRIVER_COUNT) {
  throw new Error(`Manifest contains ${manifest.length} drivers; need ${DRIVER_COUNT}`);
}

export const writes = new Counter('driver_location_writes');
export const writeErrors = new Counter('driver_location_errors');
export const writeOk = new Rate('driver_location_ok');

export const options = {
  scenarios: {
    driver_location_updates: {
      executor: 'constant-vus',
      vus: DRIVER_COUNT,
      duration: DURATION,
      gracefulStop: '30s',
      exec: 'driverLocationUpdate',
      startTime: RAMP_UP,
    },
  },
  thresholds: {
    http_req_failed: ['rate<0.005'],
    http_req_duration: ['p(95)<3000', 'p(99)<6000'],
    driver_location_ok: ['rate>0.995'],
  },
  userAgent: 'HeyCaby-k6-scale/1.0',
  setupTimeout: '30s',
};

function randomPointNear(lat, lng, radiusKm) {
  const r = radiusKm * Math.sqrt(Math.random());
  const theta = Math.random() * 2 * Math.PI;
  const dlat = (r / 111.0) * Math.cos(theta);
  const dlng = (r / (111.0 * Math.max(0.1, Math.cos((lat * Math.PI) / 180)))) * Math.sin(theta);
  return [lat + dlat, lng + dlng];
}

function isoNow() {
  return new Date().toISOString();
}

export function setup() {
  return {
    started_at: isoNow(),
    driver_count: DRIVER_COUNT,
    update_interval_sec: UPDATE_INTERVAL_SEC,
    manifest_drivers: manifest.length,
    supabase_host: SUPABASE_URL.replace(/^https?:\/\//, ''),
  };
}

export function driverLocationUpdate() {
  const actor = manifest[(__VU - 1) % DRIVER_COUNT];
  const [lat, lng] = randomPointNear(Number(actor.lat), Number(actor.lng), CENTER_RADIUS_KM);
  const body = JSON.stringify({
    user_id: actor.user_id,
    driver_id: actor.driver_id,
    latitude: Number(lat.toFixed(7)),
    longitude: Number(lng.toFixed(7)),
    heading: Math.floor(Math.random() * 360),
    country_code: 'NL',
    updated_at: isoNow(),
  });
  const params = {
    headers: {
      apikey: SUPABASE_ANON_KEY,
      Authorization: `Bearer ${actor.token}`,
      'Content-Type': 'application/json',
      Prefer: 'resolution=merge-duplicates,return=minimal',
    },
    timeout: TIMEOUT,
    tags: {
      endpoint: 'driver_locations',
      interval: String(UPDATE_INTERVAL_SEC),
    },
  };
  const res = http.post(
    `${SUPABASE_URL}/rest/v1/driver_locations?on_conflict=user_id`,
    body,
    params,
  );
  writes.add(1);
  const ok = res.status === 200 || res.status === 201 || res.status === 204;
  writeOk.add(ok);
  if (!ok) {
    writeErrors.add(1);
  }
  check(res, {
    'driver location write accepted': () => ok,
  });
  sleep(UPDATE_INTERVAL_SEC);
}

export function handleSummary(data) {
  const output = __ENV.K6_SUMMARY || 'build/load/k6_driver_location_summary.json';
  return {
    stdout: JSON.stringify(
      {
        status: 'k6 driver location run complete',
        output,
        metrics: {
          http_req_duration: data.metrics.http_req_duration,
          http_req_failed: data.metrics.http_req_failed,
          driver_location_writes: data.metrics.driver_location_writes,
          driver_location_errors: data.metrics.driver_location_errors,
          driver_location_ok: data.metrics.driver_location_ok,
          vus_max: data.metrics.vus_max,
        },
      },
      null,
      2,
    ) + '\n',
    [output]: JSON.stringify(data, null, 2),
  };
}
