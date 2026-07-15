import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const tracker = readFileSync(
  new URL("../app/track/[token]/shared-ride-tracker.tsx", import.meta.url),
  "utf8",
);
const proxy = readFileSync(
  new URL("../app/api/shared-ride/route.ts", import.meta.url),
  "utf8",
);
const nextConfig = readFileSync(
  new URL("../next.config.ts", import.meta.url),
  "utf8",
);
const edge = readFileSync(
  new URL(
    "../../../supabase/functions/get-shared-ride/index.ts",
    import.meta.url,
  ),
  "utf8",
);

test("capability token travels in POST bodies, not new query strings", () => {
  assert.match(tracker, /fetch\("\/api\/shared-ride", \{/);
  assert.match(tracker, /method: "POST"/);
  assert.doesNotMatch(tracker, /\/api\/shared-ride\?token=/);
  assert.match(proxy, /body: JSON\.stringify\(\{ token \}\)/);
  assert.doesNotMatch(proxy, /PRODUCTION_SHARED_RIDE_ENDPOINT\}\?token=/);
});

test("only loaded active rides poll and expose live location", () => {
  assert.match(tracker, /rideRef\.current != null/);
  assert.match(tracker, /rideRef\.current\.terminal !== true/);
  assert.match(edge, /if \(driverId && trackingActive\)/);
  assert.match(edge, /"declined"/);
  assert.match(edge, /"no_driver"/);
});

test("local shared-ride API wins before legacy fallback", () => {
  assert.match(nextConfig, /beforeFiles: \[\]/);
  assert.match(nextConfig, /fallback: \[/);
  assert.match(nextConfig, /source: "\/api\/:path\*"/);
});
