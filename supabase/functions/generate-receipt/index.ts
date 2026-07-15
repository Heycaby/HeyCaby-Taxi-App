import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { authenticatedUser, corsOptions, json } from "../_shared/auth.ts";

// Receipt creation is owned by the completed-ride database transaction.
// This compatibility endpoint deliberately accepts no financial inputs: the
// former implementation trusted caller-supplied driver, amount, and distance.
Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return corsOptions();
  if (req.method !== "POST") {
    return json({ ok: false, error: "method_not_allowed" }, 405);
  }

  const user = await authenticatedUser(req);
  if (user instanceof Response) return user;

  return json(
    {
      ok: false,
      error: "receipt_creation_moved_to_completed_ride",
      message:
        "Receipts are issued automatically from the authoritative completed ride.",
    },
    410,
  );
});
