import { classifyFcmError } from "./fcm_v1.ts";

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) throw new Error(message);
}

Deno.test("FCM error classification exposes stable codes only", () => {
  const invalid = classifyFcmError(JSON.stringify({
    error: {
      status: "NOT_FOUND",
      details: [{ errorCode: "UNREGISTERED" }],
      message: "sensitive provider detail",
    },
  }));
  assert(invalid.errorCode === "UNREGISTERED", "wrong stable FCM error code");
  assert(invalid.permanentFailure, "unregistered token was not permanent");

  const transient = classifyFcmError("provider body that must not escape");
  assert(transient.errorCode === "provider_error", "bad fallback error code");
  assert(!transient.permanentFailure, "unknown provider failure was permanent");
});

Deno.test("Rider delivery marks push sent only after provider acceptance", async () => {
  const index = await Deno.readTextFile(new URL("./index.ts", import.meta.url));
  const delivery = await Deno.readTextFile(
    new URL("./notify_deliver.ts", import.meta.url),
  );
  for (const source of [index, delivery]) {
    assert(
      source.includes("push.acceptedCount > 0"),
      "push_sent_at is not acceptance-gated",
    );
  }
  assert(
    !index.includes("pushed++") && !delivery.includes("pushed++"),
    "attempted sends are still counted as accepted",
  );
});
