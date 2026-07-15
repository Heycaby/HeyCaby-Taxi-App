import { apnsHostForEnvironment } from "./apns.ts";

function assertEquals(actual: unknown, expected: unknown): void {
  if (actual !== expected) {
    throw new Error(`Expected ${String(expected)}, got ${String(actual)}`);
  }
}

Deno.test("APNs host follows the signed app entitlement environment", () => {
  assertEquals(
    apnsHostForEnvironment("sandbox"),
    "api.sandbox.push.apple.com",
  );
  assertEquals(
    apnsHostForEnvironment("production"),
    "api.push.apple.com",
  );
  assertEquals(apnsHostForEnvironment(null), "api.push.apple.com");
});
