import { assertEquals } from "jsr:@std/assert@1";

import { resolveLifecycleDispatchSecret } from "./auth.ts";

Deno.test("lifecycle dispatch prefers the Rider notification domain secret", () => {
  const values: Record<string, string> = {
    RIDER_AGENT_WEBHOOK_SECRET: "canonical-secret",
    LIFECYCLE_DISPATCH_SECRET: "legacy-secret",
  };

  assertEquals(
    resolveLifecycleDispatchSecret("vault-secret", (name) => values[name]),
    "vault-secret",
  );
});

Deno.test("lifecycle dispatch falls back to the Rider Agent environment secret", () => {
  const values: Record<string, string> = {
    RIDER_AGENT_WEBHOOK_SECRET: "canonical-secret",
    LIFECYCLE_DISPATCH_SECRET: "legacy-secret",
  };

  assertEquals(
    resolveLifecycleDispatchSecret(null, (name) => values[name]),
    "canonical-secret",
  );
});

Deno.test("lifecycle dispatch retains the legacy secret as a compatibility fallback", () => {
  const values: Record<string, string> = {
    LIFECYCLE_DISPATCH_SECRET: "legacy-secret",
  };

  assertEquals(
    resolveLifecycleDispatchSecret(null, (name) => values[name]),
    "legacy-secret",
  );
});

Deno.test("lifecycle dispatch fails closed when no secret exists", () => {
  assertEquals(resolveLifecycleDispatchSecret(null, () => undefined), null);
});
