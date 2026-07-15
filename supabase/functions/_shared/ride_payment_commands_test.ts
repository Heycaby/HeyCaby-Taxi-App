import {
  refundPolicyAmounts,
  routingReversalPlan,
} from "./ride_payment_commands.ts";

function assertEquals(actual: unknown, expected: unknown): void {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`,
    );
  }
}

Deno.test("full refund returns all unrefunded backend amount", () => {
  assertEquals(
    refundPolicyAmounts({
      amountCents: 2500,
      refundedCents: 0,
      retainedFeeBps: 0,
    }),
    { refundableCents: 2500, retainedFeeCents: 0 },
  );
});

Deno.test("partial refund retains the configured fee from the original fare", () => {
  assertEquals(
    refundPolicyAmounts({
      amountCents: 2500,
      refundedCents: 0,
      retainedFeeBps: 2000,
    }),
    { refundableCents: 2000, retainedFeeCents: 500 },
  );
});

Deno.test("refund calculation cannot exceed the remaining balance", () => {
  assertEquals(
    refundPolicyAmounts({
      amountCents: 2500,
      refundedCents: 2400,
      retainedFeeBps: 2000,
    }),
    { refundableCents: 0, retainedFeeCents: 100 },
  );
});

Deno.test("refund after a partial reversal only reverses the remaining route", () => {
  assertEquals(
    routingReversalPlan({
      paymentAmountCents: 2500,
      previouslyRefundedCents: 500,
      refundAmountCents: 2000,
      routeAmountCents: 2300,
      alreadyReversedCents: 500,
    }),
    { reverseRouting: false, routingReversalCents: 1800 },
  );
});

Deno.test("first full refund uses Mollie full routing reversal", () => {
  assertEquals(
    routingReversalPlan({
      paymentAmountCents: 2500,
      previouslyRefundedCents: 0,
      refundAmountCents: 2500,
      routeAmountCents: 2300,
      alreadyReversedCents: 0,
    }),
    { reverseRouting: true, routingReversalCents: 2300 },
  );
});
