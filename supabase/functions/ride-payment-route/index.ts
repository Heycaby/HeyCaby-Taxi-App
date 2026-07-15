import {
  authenticatedUserId,
  corsOptions,
  json,
  serviceClient,
} from "../_shared/ride_payment_service.ts";
import { runRidePaymentCommand } from "../_shared/ride_payment_commands.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return corsOptions();
  if (req.method !== "POST") {
    return json({ ok: false, error: "method_not_allowed" }, 405);
  }
  const userId = await authenticatedUserId(req);
  if (userId instanceof Response) return userId;
  try {
    const body = await req.json().catch(() => ({})) as Record<string, unknown>;
    const rideId = String(body.ride_id ?? "").trim();
    if (!rideId) return json({ ok: false, error: "ride_id_required" }, 400);
    const admin = serviceClient();
    const { data: driver } = await admin.from("drivers").select("id")
      .eq("user_id", userId).maybeSingle();
    if (!driver?.id) return json({ ok: false, error: "not_a_driver" }, 403);
    const { data: ride, error } = await admin.from("ride_requests")
      .select("id, driver_id, status").eq("id", rideId).maybeSingle();
    if (error) throw error;
    if (!ride) return json({ ok: false, error: "ride_not_found" }, 404);
    if (ride.driver_id !== driver.id) {
      return json({ ok: false, error: "forbidden" }, 403);
    }
    if (ride.status !== "completed") {
      return json({ ok: false, error: "ride_not_completed" }, 409);
    }
    const result = await runRidePaymentCommand({
      admin,
      rideId,
      command: "route_completed",
      actor: { id: userId, type: "driver", source: "ride-payment-route" },
    });
    return json(result, Number("status" in result ? result.status : 200));
  } catch (error) {
    console.error("ride-payment-route", error);
    return json({ ok: false, error: "payment_route_failed" }, 502);
  }
});
