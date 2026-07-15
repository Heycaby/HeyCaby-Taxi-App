import { rejectUnauthorizedWebhook } from "./webhook_auth.ts";

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) throw new Error(message);
}

Deno.test("Rider Agent fails closed when webhook configuration is missing", async () => {
  const response = await rejectUnauthorizedWebhook(
    new Request("https://example.invalid"),
    "",
  );
  assert(response?.status === 500, "missing secret did not fail closed");
});

Deno.test("Rider Agent rejects a missing or wrong webhook secret", async () => {
  for (const supplied of ["", "wrong-secret"]) {
    const response = await rejectUnauthorizedWebhook(
      new Request("https://example.invalid", {
        headers: supplied ? { "x-webhook-secret": supplied } : {},
      }),
      "correct-secret",
    );
    assert(response?.status === 401, "invalid secret was accepted");
  }
});

Deno.test("Rider Agent accepts the exact webhook secret", async () => {
  const response = await rejectUnauthorizedWebhook(
    new Request("https://example.invalid", {
      headers: { "x-webhook-secret": "correct-secret" },
    }),
    "correct-secret",
  );
  assert(response === null, "exact secret was rejected");
});
