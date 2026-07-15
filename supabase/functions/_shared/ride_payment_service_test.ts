import {
  euroToCents,
  selectBackendFareCents,
  webhookEventKey,
} from "./ride_payment_service.ts";

function assertEquals(actual: unknown, expected: unknown): void {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`,
    );
  }
}

Deno.test("euroToCents rejects absent and non-positive fares", () => {
  assertEquals(euroToCents(null), null);
  assertEquals(euroToCents(0), null);
  assertEquals(euroToCents(-1), null);
  assertEquals(euroToCents("12.34"), 1234);
});

Deno.test("backend fare selection never accepts a client amount", () => {
  assertEquals(
    selectBackendFareCents({
      client_amount: 1,
      offered_fare: 24.5,
      quoted_fare: 20,
    }),
    { amountCents: 2450, source: "offered_fare" },
  );
  assertEquals(selectBackendFareCents({ manual_fare_cents: 1999 }), {
    amountCents: 1999,
    source: "manual_fare_cents",
  });
});

Deno.test("webhook key is stable for Mollie retries", () => {
  const payment = {
    id: "tr_test",
    status: "paid",
    amount: { currency: "EUR", value: "12.34" },
    paidAt: "2026-07-14T12:00:00Z",
  };
  assertEquals(webhookEventKey(payment), webhookEventKey({ ...payment }));
});
