import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import {
  authenticatedDriver,
  corsOptions,
  json,
  serviceClient,
} from "../_shared/auth.ts";

async function sha256(value: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return corsOptions();
  if (req.method !== "POST") {
    return json({ ok: false, error: "method_not_allowed" }, 405);
  }

  const actor = await authenticatedDriver(req);
  if (actor instanceof Response) return actor;

  const apiKey = (Deno.env.get("ILT_API_KEY") ?? "").trim();
  if (!apiKey) {
    console.error("[verify-chauffeurspas] ILT_API_KEY is not configured");
    return json({ ok: false, error: "verification_provider_unavailable" }, 503);
  }

  let body: { driver_id?: string; card_number?: string };
  try {
    body = await req.json();
  } catch {
    return json({ ok: false, error: "invalid_json" }, 400);
  }

  if (body.driver_id && body.driver_id !== actor.driverId) {
    return json({ ok: false, error: "not_authorized" }, 403);
  }

  const cardNumber = (body.card_number ?? "").replace(/[\s-]/g, "");
  if (!/^\d{6,32}$/.test(cardNumber)) {
    return json({ ok: false, error: "invalid_card_number" }, 400);
  }

  const admin = serviceClient();
  const cardHash = await sha256(cardNumber);
  const { data: duplicate, error: duplicateError } = await admin
    .from("drivers")
    .select("id")
    .eq("chauffeurspas_number_hash", cardHash)
    .neq("id", actor.driverId)
    .maybeSingle();
  if (duplicateError) {
    console.error(
      "[verify-chauffeurspas] duplicate lookup failed",
      duplicateError,
    );
    return json({ ok: false, error: "verification_unavailable" }, 500);
  }
  if (duplicate) {
    return json({ ok: false, error: "card_already_registered" }, 409);
  }

  const apiUrl = (Deno.env.get("ILT_API_URL") ??
    "https://api.ilent.nl/v1/chauffeurspas").replace(/\/$/, "");
  let providerResponse: Response;
  try {
    providerResponse = await fetch(`${apiUrl}/verify`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-API-Key": apiKey,
        Accept: "application/json",
      },
      body: JSON.stringify({ card_number: cardNumber }),
      signal: AbortSignal.timeout(15_000),
    });
  } catch (error) {
    console.error("[verify-chauffeurspas] provider request failed", error);
    return json({ ok: false, error: "verification_provider_unavailable" }, 503);
  }

  if (!providerResponse.ok) {
    console.error(
      `[verify-chauffeurspas] provider status=${providerResponse.status}`,
    );
    return json({ ok: false, error: "verification_provider_unavailable" }, 503);
  }

  const result = await providerResponse.json() as Record<string, unknown>;
  const valid = result.valid === true;
  const expiry = typeof result.expiry === "string" ? result.expiry : null;

  if (valid) {
    const { error } = await admin.from("drivers").update({
      chauffeurspas_number_hash: cardHash,
      chauffeurspas_last4: cardNumber.slice(-4),
      updated_at: new Date().toISOString(),
    }).eq("id", actor.driverId);
    if (error) {
      console.error("[verify-chauffeurspas] driver update failed", error);
      return json({ ok: false, error: "verification_save_failed" }, 500);
    }
  }

  const { error: auditError } = await admin.from("driver_verifications").insert(
    {
      driver_id: actor.driverId,
      document_type: "chauffeurspas",
      outcome: valid ? "pass" : "fail",
      verified_by: "ilt_api",
      result_data: valid
        ? {
          holder_name: result.holder_name,
          expiry,
          card_type: result.card_type,
          card_number_last4: cardNumber.slice(-4),
          issued_by: result.issued_by,
        }
        : { reason: result.reason },
      document_expiry: valid ? expiry : null,
    },
  );
  if (auditError) {
    console.error("[verify-chauffeurspas] audit insert failed", auditError);
    return json({ ok: false, error: "verification_save_failed" }, 500);
  }

  return json({
    ok: true,
    valid,
    holder_name: valid ? result.holder_name : null,
    expiry: valid ? expiry : null,
    last4: valid ? cardNumber.slice(-4) : null,
    message: valid ? "chauffeurspas_verified" : "chauffeurspas_not_verified",
  });
});
