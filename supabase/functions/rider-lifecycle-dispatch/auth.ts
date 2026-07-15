/**
 * Resolve the notification-domain webhook secret used by lifecycle cron.
 *
 * Rider Agent and lifecycle delivery are one notification domain, so the
 * Vault-backed cron caller and this Edge Function must prefer the same secret.
 * The legacy lifecycle-specific secret remains a fallback until compatibility
 * retirement is explicitly approved.
 */
export function resolveLifecycleDispatchSecret(
  vaultSecret: unknown,
  getEnv: (name: string) => string | undefined = Deno.env.get,
): string | null {
  const backend = typeof vaultSecret === "string" ? vaultSecret.trim() : "";
  if (backend) return backend;

  const canonical = getEnv("RIDER_AGENT_WEBHOOK_SECRET")?.trim();
  if (canonical) return canonical;

  const legacy = getEnv("LIFECYCLE_DISPATCH_SECRET")?.trim();
  return legacy || null;
}
