import { callbackUrl, publicVoiceBaseUrl, serviceClient, twiml, validateTwilioSignature, xmlEscape } from "../_shared/twilio_voice_service.ts";

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return twiml("<Reject reason=\"rejected\"/>");
  const params = new URLSearchParams(await req.text());
  const valid = await validateTwilioSignature(callbackUrl(req), params, req.headers.get("X-Twilio-Signature") ?? "").catch(() => false);
  if (!valid) {
    console.error("twilio_signature_invalid", { endpoint: "twiml" });
    return new Response("invalid signature", { status: 403 });
  }
  const attemptId = new URL(req.url).searchParams.get("attempt_id") ?? "";
  const admin = serviceClient();
  const context = await admin.rpc("fn_masked_call_routing_context", { p_attempt_id: attemptId });
  if (context.error || context.data?.ok !== true) return twiml("<Say>Calling is unavailable.</Say>");
  const permission = await admin.rpc("fn_authorize_masked_call_attempt", { p_attempt_id: attemptId });
  if (permission.error || permission.data?.can_call !== true) return twiml("<Say>The communication window has ended.</Say>");
  const maxSeconds = Math.min(Math.max(Number(context.data.max_call_seconds ?? 300), 1), 300);
  const callback = `${publicVoiceBaseUrl()}/twilio-voice-status-webhook?attempt_id=${encodeURIComponent(attemptId)}`;
  return twiml(`<Dial callerId="${xmlEscape(String(context.data.masked_number))}" timeLimit="${maxSeconds}" record="do-not-record" action="${xmlEscape(callback)}" method="POST"><Number>${xmlEscape(String(context.data.recipient_phone))}</Number></Dial>`);
});
