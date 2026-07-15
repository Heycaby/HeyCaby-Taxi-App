import { json, safeCompare } from "./util.ts";

/** Returns an error response, or null when the request is authenticated. */
export async function rejectUnauthorizedWebhook(
  req: Request,
  expectedSecret: string,
): Promise<Response | null> {
  if (!expectedSecret) return json({ error: "Misconfigured" }, 500);

  const incomingSecret = req.headers.get("x-webhook-secret") ?? "";
  if (!await safeCompare(incomingSecret, expectedSecret)) {
    return json({ error: "Unauthorized" }, 401);
  }
  return null;
}
