import { contentFor } from "./notify_live_activity.ts";

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) throw new Error(message);
}

function ride(paymentStatus: string | null, status = "completed") {
  return {
    id: "ride-test",
    status,
    destination_address: "Rotterdam Centraal",
    driver_arrived_at: null,
    waiting_grace_seconds: 120,
    waiting_fee_cents: 0,
    waiting_fee_waived: false,
    payment_status: paymentStatus,
    estimated_duration_min: 12,
    updated_at: "2026-07-14T06:45:00Z",
  };
}

Deno.test("canonical confirmed payment ends the Live Activity", () => {
  const payload = contentFor(
    ride("confirmed"),
    "trip_completed",
    "Payment received",
    "Thanks for riding.",
  );

  assert(payload.event === "end", "confirmed payment did not end activity");
  assert(
    payload.state.phase === "completed",
    "confirmed payment stayed pending",
  );
  assert(
    payload.state.progressPercent === 100,
    "confirmed payment not complete",
  );
});

Deno.test("legacy paid remains compatible", () => {
  const payload = contentFor(
    ride("paid"),
    "trip_completed",
    "Payment received",
    "Thanks for riding.",
  );
  assert(payload.event === "end", "legacy paid stopped ending activity");
});

Deno.test("completed ride without confirmed payment remains payment pending", () => {
  const payload = contentFor(
    ride("pending"),
    "trip_completed",
    "Trip completed",
    "Confirm payment.",
  );

  assert(payload.event === "update", "unpaid trip ended the activity");
  assert(
    payload.state.phase === "payment",
    "unpaid trip skipped payment phase",
  );
});
