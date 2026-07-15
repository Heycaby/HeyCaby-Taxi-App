import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createHmac, timingSafeEqual } from "node:crypto";
import { isUuid, json, serviceClient } from "../_shared/auth.ts";

function verifySignature(
  body: string,
  supplied: string,
  secret: string,
): boolean {
  if (!/^[0-9a-f]{64}$/i.test(supplied)) return false;
  const expected = createHmac("sha256", secret).update(body).digest();
  const actual = Buffer.from(supplied, "hex");
  return actual.length === expected.length && timingSafeEqual(actual, expected);
}

function dateOnly(value: unknown): string | null {
  if (typeof value !== "string" || !value.trim()) return null;
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime())
    ? null
    : parsed.toISOString().split("T")[0];
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return json({ ok: false, error: "method_not_allowed" }, 405);
  }

  const secret = (Deno.env.get("VERIFF_SHARED_SECRET") ?? "").trim();
  if (!secret) {
    console.error("[veriff-webhook] VERIFF_SHARED_SECRET is missing");
    return json({ ok: false, error: "webhook_not_configured" }, 503);
  }

  const rawBody = await req.text();
  const signature = req.headers.get("x-hmac-signature") ?? "";
  if (!verifySignature(rawBody, signature, secret)) {
    console.warn("[veriff-webhook] invalid signature");
    return json({ ok: false, error: "invalid_signature" }, 403);
  }

  let body: Record<string, unknown>;
  try {
    body = JSON.parse(rawBody);
  } catch {
    return json({ ok: false, error: "invalid_json" }, 400);
  }

  const admin = serviceClient();
  const verification = body.verification as Record<string, unknown> | undefined;
  if (verification) {
    const driverId = verification.vendorData;
    if (!isUuid(driverId)) {
      return json({ ok: false, error: "invalid_vendor_data" }, 400);
    }

    const decision = typeof verification.status === "string"
      ? verification.status
      : "unknown";
    if (
      !["approved", "declined", "resubmission_requested"].includes(decision)
    ) {
      return json({ ok: false, error: "invalid_decision" }, 400);
    }

    const person = verification.person as Record<string, unknown> | undefined;
    const document = verification.document as
      | Record<string, unknown>
      | undefined;
    const additional = verification.additionalVerifiedData as
      | Record<string, unknown>
      | undefined;
    const approved = decision === "approved";
    const now = new Date().toISOString();
    const update: Record<string, unknown> = {
      veriff_session_id: verification.id ?? null,
      veriff_attempt_id: verification.attemptId ?? null,
      veriff_status: decision,
      veriff_decision: decision,
      veriff_completed_at: verification.decisionTime ?? now,
      updated_at: now,
    };

    if (approved) {
      update.rijbewijs_verified = true;
      update.rijbewijs_verified_at = now;
    }

    if (person) {
      const name = [person.firstName, person.lastName]
        .filter((part) => typeof part === "string" && part.trim())
        .join(" ")
        .trim();
      if (name) update.veriff_full_name = name;
      const dob = dateOnly(person.dateOfBirth);
      if (dob) update.veriff_dob = dob;
    }

    if (document) {
      if (typeof document.number === "string") {
        update.veriff_id_number = document.number;
      }
      const expiry = dateOnly(document.validUntil);
      if (expiry) {
        update.veriff_id_expiry = expiry;
        update.rijbewijs_expiry = expiry;
      }
    }

    const categoryExpiry = additional?.driversLicenseCategoryUntil;
    if (categoryExpiry && typeof categoryExpiry === "object") {
      const dates = Object.values(categoryExpiry as Record<string, unknown>)
        .map(dateOnly)
        .filter((value): value is string => value !== null)
        .sort();
      if (dates.length > 0) {
        update.veriff_id_expiry = dates[dates.length - 1];
        update.rijbewijs_expiry = dates[dates.length - 1];
      }
    }

    const riskLabels: string[] = [];
    if (body.riskScore !== undefined) {
      riskLabels.push(`riskScore:${String(body.riskScore)}`);
    }
    if (verification.reasonCode !== undefined) {
      riskLabels.push(`reasonCode:${String(verification.reasonCode)}`);
    }
    if (riskLabels.length > 0) update.veriff_risk_labels = riskLabels;

    const { data: driver, error: updateError } = await admin
      .from("drivers")
      .update(update)
      .eq("id", driverId)
      .select("user_id")
      .maybeSingle();
    if (updateError || !driver) {
      console.error("[veriff-webhook] driver update failed", updateError);
      return json({ ok: false, error: "driver_update_failed" }, 500);
    }

    if (approved) {
      const { error } = await admin.from("driver_onboarding_steps").update({
        sub_rijbewijs_done: true,
        updated_at: now,
      }).eq("driver_id", driverId);
      if (error) {
        console.error("[veriff-webhook] onboarding update failed", error);
        return json({ ok: false, error: "onboarding_update_failed" }, 500);
      }
    }

    const title = approved
      ? "Rijbewijs geverifieerd ✓"
      : decision === "resubmission_requested"
      ? "Verificatie: actie vereist"
      : "Verificatie niet geslaagd";
    const message = approved
      ? "Je rijbewijs is succesvol geverifieerd via Veriff."
      : decision === "resubmission_requested"
      ? "Veriff heeft extra documenten nodig. Open de app om opnieuw te verifiëren."
      : "Je rijbewijsverificatie is niet geslaagd. Neem contact op met support.";
    const { error: notificationError } = await admin.from("notifications")
      .insert({
        user_type: "driver",
        user_id: driver.user_id,
        agent: "verification",
        category: "verification",
        title,
        body: message,
        data: { type: "veriff_decision", decision, driver_id: driverId },
        priority: approved ? "medium" : "high",
        channel: "both",
      });
    if (notificationError) {
      console.error(
        "[veriff-webhook] notification intent failed",
        notificationError,
      );
    }

    console.log(`[veriff-webhook] decision=${decision} driver=${driverId}`);
    return json({ ok: true, received: true });
  }

  const action = body.action;
  const driverId = body.vendorData;
  const sessionId = body.id;
  if (typeof action === "string") {
    if (!isUuid(driverId) || typeof sessionId !== "string" || !sessionId) {
      return json({ ok: false, error: "invalid_event" }, 400);
    }
    const statuses: Record<string, string> = {
      started: "started",
      submitted: "submitted",
      expired: "expired",
      abandoned: "expired",
    };
    const status = statuses[action];
    if (!status) return json({ ok: false, error: "invalid_action" }, 400);

    const { error } = await admin.from("drivers").update({
      veriff_session_id: sessionId,
      veriff_status: status,
      updated_at: new Date().toISOString(),
    }).eq("id", driverId);
    if (error) {
      console.error("[veriff-webhook] event update failed", error);
      return json({ ok: false, error: "driver_update_failed" }, 500);
    }
    return json({ ok: true, received: true });
  }

  return json({ ok: false, error: "unknown_payload" }, 400);
});
