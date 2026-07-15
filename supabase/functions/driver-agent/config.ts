import { createClient } from "jsr:@supabase/supabase-js";

export const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
export const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
export const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const configuredWebhookSecret = Deno.env.get("AGENT_WEBHOOK_SECRET") ?? "";
export { createClient };

let cachedWebhookSecret: string | null = null;

/**
 * Edge Function secrets remain the preferred source. The RPC fallback reads the
 * existing Vault secret and is executable by service_role only, so database
 * webhooks continue to work if an Edge Function redeploy loses its env secret.
 */
export async function resolveWebhookSecret(): Promise<string> {
  if (configuredWebhookSecret) return configuredWebhookSecret;
  if (cachedWebhookSecret) return cachedWebhookSecret;

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const result = await supabase.rpc("fn_driver_agent_webhook_secret") as {
    data: unknown;
    error: { code?: string } | null;
  };
  const { data, error } = result;
  if (error) {
    console.error(
      "driver-agent: webhook secret is unavailable from env and Vault bridge",
      error.code ?? "unknown",
    );
    return "";
  }

  const secret = typeof data === "string" ? data.trim() : "";
  if (secret) cachedWebhookSecret = secret;
  return secret;
}
