import type { SupabaseClient } from "jsr:@supabase/supabase-js";

import type { AgentNotificationRow } from "./notify_types.ts";

export type PingKind =
  | "on_my_way"
  | "outside"
  | "nearby"
  | "arrived"
  | "running_late"
  | "traffic_delay"
  | "cant_find_rider"
  | "thanks";

const COOLDOWN_MS = 30_000;

export function normalizePingKind(raw: string | undefined): PingKind | null {
  const k = (raw ?? "").trim().toLowerCase();
  if (k === "nearby") return "on_my_way";
  const allowed: PingKind[] = [
    "on_my_way",
    "outside",
    "arrived",
    "running_late",
    "traffic_delay",
    "cant_find_rider",
    "thanks",
  ];
  return allowed.includes(k as PingKind) ? (k as PingKind) : null;
}

export function pingAuditEvent(kind: PingKind): string {
  const normalized = kind === "nearby" ? "on_my_way" : kind;
  return `driver.ping_${normalized}`;
}

export function pingNotificationCategory(kind: PingKind): string {
  const normalized = kind === "nearby" ? "on_my_way" : kind;
  return `driver_ping_${normalized}`;
}

function vehicleLabel(
  driver: Record<string, unknown> | null | undefined,
): string {
  if (!driver) return "";
  const make = (driver.rdw_merk ?? driver.vehicle_make ?? "") as string;
  const model =
    (driver.rdw_handelsbenaming ?? driver.vehicle_model ?? "") as string;
  return [make, model].map((s) => s.trim()).filter(Boolean).join(" ");
}

function formatPlate(raw: string): string {
  const c = raw.replace(/[\s-]/g, "").toUpperCase();
  if (c.length <= 6) return c;
  return c;
}

export function buildPingCopy(
  kind: PingKind,
  driver: Record<string, unknown> | null | undefined,
  etaMinutes?: number | null,
): {
  title: string;
  body: string;
  priority: AgentNotificationRow["priority"];
  channelId: string;
} {
  const vehicle = vehicleLabel(driver);
  const plateRaw = ((driver?.vehicle_plate ?? "") as string).trim();
  const plate = plateRaw ? formatPlate(plateRaw) : "";
  const vehicleBlock = vehicle || plate
    ? `\n\nVoertuig: ${vehicle || "—"}${plate ? `\nKenteken: ${plate}` : ""}`
    : "";
  const etaBlock = etaMinutes != null && etaMinutes > 0
    ? `\n\nETA: ${etaMinutes} minuten`
    : "";

  switch (kind === "nearby" ? "on_my_way" : kind) {
    case "outside":
      return {
        title: "Chauffeur staat buiten",
        body:
          `Je chauffeur wacht buiten.${vehicleBlock}\n\nKom alsjeblieft naar buiten.`,
        priority: "critical",
        channelId: "heycaby_ping_urgent",
      };
    case "arrived":
      return {
        title: "Chauffeur is aangekomen",
        body: `Je chauffeur is bij het ophaalpunt.${vehicleBlock}`,
        priority: "high",
        channelId: "heycaby_ping_urgent",
      };
    case "running_late":
      return {
        title: "Chauffeur heeft vertraging",
        body: `Je chauffeur laat weten dat hij iets later is.${etaBlock}`,
        priority: "high",
        channelId: "heycaby_ping_standard",
      };
    case "traffic_delay":
      return {
        title: "Vertraging door verkeer",
        body: `Je chauffeur heeft vertraging door verkeer.${etaBlock}`,
        priority: "high",
        channelId: "heycaby_ping_standard",
      };
    case "cant_find_rider":
      return {
        title: "Chauffeur kan je niet vinden",
        body:
          `Je chauffeur kan je niet vinden. Stuur een chatbericht of kom naar buiten.${vehicleBlock}`,
        priority: "critical",
        channelId: "heycaby_ping_urgent",
      };
    case "thanks":
      return {
        title: "Bedankt!",
        body: "Je chauffeur bedankt je voor de rit.",
        priority: "medium",
        channelId: "heycaby_ping_soft",
      };
    case "on_my_way":
    default:
      return {
        title: "Chauffeur onderweg",
        body:
          `Je chauffeur is onderweg naar het ophaalpunt.${etaBlock}${vehicleBlock}`,
        priority: "high",
        channelId: "heycaby_ping_standard",
      };
  }
}

export async function recentPingCooldown(
  supabase: SupabaseClient,
  rideRequestId: string,
  event: string,
): Promise<boolean> {
  const since = new Date(Date.now() - COOLDOWN_MS).toISOString();
  const { data } = await supabase
    .from("ride_audit_log")
    .select("id")
    .eq("ride_id", rideRequestId)
    .eq("event", event)
    .gte("occurred_at", since)
    .limit(1);
  return (data?.length ?? 0) > 0;
}

/** Automatic pings fire at most once per ride + event. */
export async function hasAutomaticPing(
  supabase: SupabaseClient,
  rideRequestId: string,
  event: string,
): Promise<boolean> {
  const { data } = await supabase
    .from("ride_audit_log")
    .select("id")
    .eq("ride_id", rideRequestId)
    .eq("event", event)
    .contains("metadata", { automatic: true })
    .limit(1);
  return (data?.length ?? 0) > 0;
}

export async function appendPingAudit(
  supabase: SupabaseClient,
  rideRequestId: string,
  event: string,
  actorUserId: string | null,
  metadata: Record<string, unknown>,
): Promise<void> {
  await supabase.rpc("fn_ride_audit_append", {
    p_ride_id: rideRequestId,
    p_event: event,
    p_actor_id: actorUserId,
    p_metadata: metadata,
  });
}
