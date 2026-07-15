import { corsOptions, createBridgeCall, json, serviceClient, userClient } from "../_shared/twilio_voice_service.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return corsOptions();
  if (req.method !== "POST") return json({ ok: false, error: "method_not_allowed" }, 405);
  let attemptId = "";
  try {
    const body = await req.json().catch(() => ({})) as Record<string, unknown>;
    const rideId = String(body.ride_request_id ?? "").trim();
    const idempotencyKey = String(body.idempotency_key ?? "").trim();
    if (!rideId || !idempotencyKey) return json({ ok: false, error: "invalid_request" }, 400);

    const client = userClient(req);
    const { data: authData, error: authError } = await client.auth.getUser();
    if (authError || !authData.user) return json({ ok: false, error: "unauthorized" }, 401);
    const intent = await client.rpc("fn_create_masked_call_intent", {
      p_ride_request_id: rideId, p_idempotency_key: idempotencyKey,
    });
    if (intent.error) throw intent.error;
    if (intent.data?.ok !== true) return json({ ok: false, error: intent.data?.code ?? "calling_unavailable" }, 409);
    attemptId = String(intent.data.attempt_id ?? "");
    if (intent.data.idempotent_replay === true && intent.data.status !== "requested") {
      return json({ ok: true, attempt_id: attemptId, status: intent.data.status, idempotent_replay: true });
    }

    const admin = serviceClient();
    const context = await admin.rpc("fn_masked_call_routing_context", { p_attempt_id: attemptId });
    if (context.error) throw context.error;
    if (context.data?.ok !== true) return json({ ok: false, error: context.data?.code ?? "routing_unavailable" }, 409);
    const call = await createBridgeCall({
      attemptId,
      from: String(context.data.masked_number),
      initiator: String(context.data.initiator_phone),
    });
    const updated = await admin.rpc("fn_update_masked_call_attempt", {
      p_attempt_id: attemptId, p_status: call.status === "queued" ? "queued" : "initiated",
      p_twilio_call_sid: call.sid,
    });
    if (updated.error) throw updated.error;
    return json({ ok: true, attempt_id: attemptId, status: updated.data?.status ?? "queued" }, 202);
  } catch (error) {
    console.error("ride_masked_call_start_failed", { attemptId, message: error instanceof Error ? error.message : "unknown" });
    if (attemptId) {
      try {
        await serviceClient().rpc("fn_update_masked_call_attempt", {
          p_attempt_id: attemptId, p_status: "failed", p_failure_code: "provider_start_failed",
          p_failure_message: error instanceof Error ? error.message : "unknown",
        });
      } catch (_) { /* The original provider failure remains the response authority. */ }
    }
    return json({ ok: false, error: "calling_temporarily_unavailable" }, 503);
  }
});
