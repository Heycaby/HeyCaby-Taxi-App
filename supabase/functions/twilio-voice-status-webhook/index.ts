import { callbackUrl, normalizeCallStatus, serviceClient, validateTwilioSignature } from "../_shared/twilio_voice_service.ts";

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return new Response("ok");
  const raw = await req.text();
  const params = new URLSearchParams(raw);
  const supplied = req.headers.get("X-Twilio-Signature") ?? "";
  const valid = await validateTwilioSignature(callbackUrl(req), params, supplied).catch(() => false);
  const attemptId = new URL(req.url).searchParams.get("attempt_id") ?? "";
  const callSid = params.get("CallSid") ?? params.get("DialCallSid") ?? "";
  const eventType = params.get("CallStatus") ?? params.get("DialCallStatus") ?? "unknown";
  const eventKey = `${attemptId}:${callSid}:${eventType}:${params.get("Timestamp") ?? params.get("SequenceNumber") ?? "final"}`;
  const admin = serviceClient();
  await admin.rpc("fn_record_twilio_voice_webhook", {
    p_event_key: eventKey, p_call_sid: callSid, p_event_type: eventType,
    p_payload_redacted: {
      call_status: eventType, dial_call_status: params.get("DialCallStatus"),
      call_duration: params.get("CallDuration"), dial_call_duration: params.get("DialCallDuration"),
      error_code: params.get("ErrorCode"), sequence_number: params.get("SequenceNumber"),
    }, p_signature_valid: valid,
    p_processing_error: valid ? null : "invalid_signature",
  });
  if (!valid) {
    console.error("twilio_signature_invalid", { endpoint: "status" });
    return new Response("invalid signature", { status: 403 });
  }
  const duration = Number(params.get("DialCallDuration") ?? params.get("CallDuration") ?? 0);
  const result = await admin.rpc("fn_update_masked_call_attempt", {
    p_attempt_id: attemptId, p_status: normalizeCallStatus(eventType),
    p_twilio_call_sid: callSid || null, p_parent_call_sid: params.get("ParentCallSid"),
    p_duration_seconds: Number.isFinite(duration) ? Math.round(duration) : null,
    p_price: params.get("Price") ? Number(params.get("Price")) : null,
    p_price_unit: params.get("PriceUnit"), p_failure_code: params.get("ErrorCode"),
  });
  if (result.error || result.data?.ok !== true) {
    console.error("twilio_callback_update_failed", { attemptId, code: result.data?.code });
    return new Response("update failed", { status: 500 });
  }
  return new Response("ok");
});

