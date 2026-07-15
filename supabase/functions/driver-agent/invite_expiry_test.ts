import { buildAgentNotification } from "./notify_rules.ts";
import { incomingRideGate, notificationDeliveryGate } from "./invite_gate.ts";
import type { AgentNotificationRow, WebhookPayload } from "./notify_types.ts";

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) throw new Error(message);
}

function invitePayload(expiresAt: string, status = "pending"): WebhookPayload {
  return {
    type: "INSERT",
    table: "ride_request_invites",
    record: {
      id: "invite-test",
      ride_request_id: "ride-test",
      driver_id: "driver-test",
      status,
      expires_at: expiresAt,
    },
  };
}

function incomingNotification(): AgentNotificationRow {
  return {
    target: "driver",
    user_type: "driver",
    user_id: "driver-test",
    agent: "driver_agent",
    category: "incoming_ride",
    title: "New ride",
    body: "Open the exact invite.",
    data: {
      ride_invite_id: "invite-test",
      ride_request_id: "ride-test",
    },
    priority: "high",
    channel: "both",
  };
}

function taxiTerugOfferNotification(
  newFare = 65,
): AgentNotificationRow {
  return {
    target: "driver",
    user_type: "driver",
    user_id: "driver-test",
    agent: "driver_agent",
    category: "taxi_terug_offer_increased",
    title: "Taxi Terug offer increased",
    body: "New offer: €65.",
    data: {
      source_event_id: "event-test",
      ride_request_id: "ride-test",
      booking_mode: "terug",
      new_fare: newFare,
    },
    priority: "high",
    channel: "both",
  };
}

function gateClient(
  invite: Record<string, unknown> | null,
  ride: Record<string, unknown> | null,
): Parameters<typeof incomingRideGate>[0] {
  return {
    from(table: string) {
      const query = {
        select() {
          return query;
        },
        eq() {
          return query;
        },
        maybeSingle() {
          return Promise.resolve({
            data: table === "ride_request_invites" ? invite : ride,
            error: null,
          });
        },
      };
      return query;
    },
  } as unknown as Parameters<typeof incomingRideGate>[0];
}

Deno.test("expired and non-pending invites never build push intent", () => {
  const expired = new Date(Date.now() - 1_000).toISOString();
  const future = new Date(Date.now() + 60_000).toISOString();
  assert(
    buildAgentNotification(invitePayload(expired)) === null,
    "expired invite created a notification",
  );
  assert(
    buildAgentNotification(invitePayload(future, "superseded")) === null,
    "non-pending invite created a notification",
  );
});

Deno.test("live invite intent carries exact IDs and server expiry", () => {
  const future = new Date(Date.now() + 60_000).toISOString();
  const notification = buildAgentNotification(invitePayload(future));
  assert(notification?.category === "incoming_ride", "wrong category");
  assert(
    notification.data?.ride_invite_id === "invite-test",
    "missing exact invite ID",
  );
  assert(
    notification.data?.ride_request_id === "ride-test",
    "missing ride ID",
  );
  assert(notification.data?.expires_at === future, "missing server expiry");
});

Deno.test("chat intents keep one source event ID in both directions", () => {
  const riderMessage = buildAgentNotification({
    type: "INSERT",
    table: "messages",
    record: {
      id: "message-rider-test",
      ride_request_id: "ride-test",
      sender_type: "rider",
      content: "I am outside",
    },
  });
  assert(riderMessage?.category === "chat", "rider chat intent missing");
  assert(
    riderMessage.data?.message_id === "message-rider-test" &&
      riderMessage.data?.source_event_id === "message-rider-test",
    "rider chat correlation is not bound to the message row",
  );

  const driverMessage = buildAgentNotification({
    type: "INSERT",
    table: "messages",
    record: {
      id: "message-driver-test",
      ride_request_id: "ride-test",
      sender_type: "driver",
      content: "Two minutes away",
    },
  });
  assert(driverMessage?.category === "chat", "driver chat intent missing");
  assert(
    driverMessage.data?.message_id === "message-driver-test" &&
      driverMessage.data?.source_event_id === "message-driver-test",
    "driver chat fallback correlation is not bound to the message row",
  );
  assert(
    driverMessage.data?.signal_kind === "driver_message",
    "driver chat fallback lost its canonical signal kind",
  );
});

Deno.test("delivery gate rejects expired invite and terminal ride", async () => {
  const future = new Date(Date.now() + 60_000).toISOString();
  const expired = new Date(Date.now() - 1_000).toISOString();

  const expiredGate = await incomingRideGate(
    gateClient({
      id: "invite-test",
      ride_request_id: "ride-test",
      driver_id: "driver-test",
      status: "pending",
      expires_at: expired,
    }, null),
    incomingNotification(),
  );
  assert(
    !expiredGate.live && expiredGate.reason === "invite_expired",
    "expired invite passed the delivery gate",
  );

  const terminalGate = await incomingRideGate(
    gateClient({
      id: "invite-test",
      ride_request_id: "ride-test",
      driver_id: "driver-test",
      status: "pending",
      expires_at: future,
    }, {
      status: "cancelled",
      driver_id: null,
      expires_at: future,
    }),
    incomingNotification(),
  );
  assert(
    !terminalGate.live && terminalGate.reason === "ride_not_open",
    "terminal ride passed the delivery gate",
  );
});

Deno.test("delivery gate returns the earliest authoritative expiry", async () => {
  const inviteExpiry = new Date(Date.now() + 120_000).toISOString();
  const rideExpiry = new Date(Date.now() + 60_000).toISOString();
  const gate = await incomingRideGate(
    gateClient({
      id: "invite-test",
      ride_request_id: "ride-test",
      driver_id: "driver-test",
      status: "pending",
      expires_at: inviteExpiry,
    }, {
      status: "pending",
      driver_id: null,
      expires_at: rideExpiry,
    }),
    incomingNotification(),
  );
  assert(gate.live, "live invite was rejected");
  assert(
    gate.expiresAt === rideExpiry,
    "provider expiry did not use the earliest authoritative deadline",
  );
});

Deno.test("live Taxi Terug offer increase passes the delivery gate", async () => {
  const gate = await notificationDeliveryGate(
    gateClient(null, {
      booking_mode: "terug",
      status: "pending",
      driver_id: null,
      expires_at: new Date(Date.now() + 60_000).toISOString(),
      marketplace_offered_fare: 65,
    }),
    taxiTerugOfferNotification(),
  );
  assert(gate.live, "live Taxi Terug offer increase was rejected");
});

Deno.test("Taxi Terug offer gate rejects terminal or assigned rides", async () => {
  const terminal = await notificationDeliveryGate(
    gateClient(null, {
      booking_mode: "terug",
      status: "cancelled",
      driver_id: null,
      expires_at: new Date(Date.now() + 60_000).toISOString(),
      marketplace_offered_fare: 65,
    }),
    taxiTerugOfferNotification(),
  );
  assert(
    !terminal.live && terminal.reason === "ride_not_open",
    "terminal Taxi Terug ride passed the delivery gate",
  );

  const assigned = await notificationDeliveryGate(
    gateClient(null, {
      booking_mode: "terug",
      status: "pending",
      driver_id: "assigned-driver",
      expires_at: new Date(Date.now() + 60_000).toISOString(),
      marketplace_offered_fare: 65,
    }),
    taxiTerugOfferNotification(),
  );
  assert(
    !assigned.live && assigned.reason === "ride_already_assigned",
    "assigned Taxi Terug ride passed the delivery gate",
  );
});

Deno.test("Taxi Terug offer gate rejects a superseded fare", async () => {
  const gate = await notificationDeliveryGate(
    gateClient(null, {
      booking_mode: "terug",
      status: "pending",
      driver_id: null,
      expires_at: new Date(Date.now() + 60_000).toISOString(),
      marketplace_offered_fare: 70,
    }),
    taxiTerugOfferNotification(65),
  );
  assert(
    !gate.live && gate.reason === "offer_superseded",
    "superseded Taxi Terug fare passed the delivery gate",
  );
});

Deno.test("provider transports enforce the invite expiry", async () => {
  const fcm = await Deno.readTextFile(new URL("./fcm_v1.ts", import.meta.url));
  const apns = await Deno.readTextFile(new URL("./apns.ts", import.meta.url));
  const delivery = await Deno.readTextFile(
    new URL("./notify_deliver.ts", import.meta.url),
  );

  assert(fcm.includes("ttl: `${ttlSeconds}s`"), "Android TTL missing");
  assert(fcm.includes('"apns-expiration"'), "FCM APNs expiry missing");
  assert(apns.includes('"apns-expiration"'), "direct APNs expiry missing");
  assert(
    !fcm.includes("FULL ERROR RESPONSE") &&
      !delivery.includes("push_error_details"),
    "provider response details must not be logged or persisted",
  );
  assert(
    delivery.includes("const sendGate = await notificationDeliveryGate"),
    "pre-provider live gate missing",
  );
});
