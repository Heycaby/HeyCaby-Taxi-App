import {
  authenticatedUserId,
  corsOptions,
  json,
  serviceClient,
} from "../_shared/ride_payment_service.ts";
import {
  RidePaymentCommand,
  runRidePaymentCommand,
} from "../_shared/ride_payment_commands.ts";

const commands: Record<string, RidePaymentCommand> = {
  admin_refund_ride_payment: "refund_full",
  admin_partial_refund: "refund_partial",
  admin_apply_cancellation_fee: "capture_cancellation_fee",
  admin_apply_no_show_fee: "capture_no_show_fee",
  admin_retry_payment_route: "route_completed",
  admin_void_unrouted_payment: "void_unrouted",
};

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
    const action = String(body.action ?? "").trim();
    const reason = String(body.reason ?? "").trim();
    if (!rideId) return json({ ok: false, error: "ride_id_required" }, 400);
    if (!commands[action]) {
      return json({ ok: false, error: "invalid_action" }, 400);
    }
    if (reason.length < 3 || reason.length > 1000) {
      return json({ ok: false, error: "admin_reason_required" }, 400);
    }
    const admin = serviceClient();
    const { data: adminUser, error } = await admin.from("admin_users")
      .select("id, role, permissions, is_active").eq("user_id", userId)
      .eq("is_active", true).maybeSingle();
    if (error) throw error;
    if (!adminUser) return json({ ok: false, error: "admin_required" }, 403);
    if (!["admin", "super_admin"].includes(String(adminUser.role ?? ""))) {
      return json({ ok: false, error: "admin_role_not_authorized" }, 403);
    }
    const result = await runRidePaymentCommand({
      admin,
      rideId,
      command: commands[action],
      actor: {
        id: userId,
        type: "admin",
        reason,
        source: "ride-payment-admin-command",
      },
    });
    return json(result, Number("status" in result ? result.status : 200));
  } catch (error) {
    console.error("ride-payment-admin-command", error);
    return json({ ok: false, error: "payment_command_failed" }, 502);
  }
});
