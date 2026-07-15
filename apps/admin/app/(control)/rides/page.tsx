import type { Metadata } from "next";
import Link from "next/link";
import { adminRpc } from "@/lib/admin";
import { dateTime, euros, shortId } from "@/lib/format";
import { Empty, PageHeader, Section, Status } from "@/components/ui";

export const metadata: Metadata = { title: "Rides" };

type Ride = {
  id: string; status: string; booking_mode: string; is_scheduled: boolean;
  scheduled_pickup_at: string; payment_method: string; payment_status: string;
  offered_fare: number; final_fare: number; currency: string; driver_name: string;
  created_at: string; pickup_area: string; destination_area: string;
};
type Evidence = {
  ok: boolean;
  ride: Record<string, unknown>;
  verification?: Record<string, unknown>;
  pickup_versions: Array<Record<string, unknown>>;
  contacts: Array<Record<string, unknown>>;
  cases: Array<Record<string, unknown>>;
  events: Array<Record<string, unknown>>;
  payment?: Record<string, unknown>;
  route_summary?: Record<string, unknown>;
};

const show = (value: unknown) => value === null || value === undefined
  ? "—"
  : typeof value === "object" ? JSON.stringify(value) : String(value);

export default async function RidesPage({
  searchParams,
}: {
  searchParams: Promise<{ status?: string; ride?: string }>;
}) {
  const p = await searchParams;
  const rows = await adminRpc<Ride[]>("fn_admin_os_rides", {
    p_status: p.status || null,
    p_limit: 100,
  });
  const evidence = p.ride
    ? await adminRpc<Evidence>("fn_admin_ride_evidence_timeline", { p_ride_id: p.ride })
    : null;

  return <>
    <PageHeader
      eyebrow="Canonical lifecycle"
      title="Rides"
      description="Ride operations and the backend-owned verification, route, support, and payment evidence timeline."
    />
    {evidence?.ok && <Section
      title={`Evidence file #${shortId(p.ride!)}`}
      description="Privacy-scoped operational evidence. Boarding secrets and provider payloads are never exposed."
      action={<Link className="button button-small" href={`/rides${p.status ? `?status=${p.status}` : ""}`}>Close</Link>}
    >
      <div className="stats-grid">
        <article className="stat-card"><div><span>Ride state</span></div><strong>{show(evidence.ride.status)}</strong><p>{show(evidence.ride.booking_mode)}</p></article>
        <article className="stat-card"><div><span>Risk</span></div><strong>{show(evidence.verification?.risk_status ?? "not protected")}</strong><p>{show(evidence.verification?.risk_reasons)}</p></article>
        <article className="stat-card"><div><span>Route evidence</span></div><strong>{show(evidence.route_summary?.samples ?? 0)} samples</strong><p>{dateTime(show(evidence.route_summary?.last_at))}</p></article>
        <article className="stat-card"><div><span>Payment</span></div><strong>{show(evidence.payment?.state ?? "none")}</strong><p>Eligible: {dateTime(show(evidence.verification?.payment_eligible_at))}</p></article>
      </div>
      <div className="table-wrap">
        <table><thead><tr><th>Time</th><th>Event</th><th>Actor / source</th><th>Evidence</th></tr></thead>
          <tbody>{evidence.events.map((event, i) => <tr key={show(event.id) || i}>
            <td>{dateTime(show(event.occurred_at))}</td>
            <td><strong>{show(event.event).replaceAll("_", " ")}</strong></td>
            <td>{show(event.actor_type)}<small>{show(event.source)}</small></td>
            <td><small>{show(event.metadata)}</small></td>
          </tr>)}</tbody>
        </table>
      </div>
      {(evidence.cases.length > 0 || evidence.contacts.length > 0 || evidence.pickup_versions.length > 0) && <details>
        <summary>Supporting evidence</summary>
        <pre>{JSON.stringify({ pickup_versions: evidence.pickup_versions, contacts: evidence.contacts, cases: evidence.cases }, null, 2)}</pre>
      </details>}
    </Section>}
    <Section
      title="Ride activity"
      description="Latest 100 rides"
      action={<form className="filters"><select name="status" defaultValue={p.status || ""}><option value="">All states</option><option value="accepted">Accepted</option><option value="driver_arrived">Driver arrived</option><option value="in_progress">In progress</option><option value="completed">Completed</option><option value="cancelled">Cancelled</option></select><button className="button button-small">Filter</button></form>}
    >
      {rows.length === 0 ? <Empty title="No rides found" body="There are no rides matching this state." /> : <div className="table-wrap"><table><thead><tr><th>Ride</th><th>Route</th><th>Mode</th><th>Driver</th><th>Fare</th><th>Payment</th><th>Created</th></tr></thead><tbody>{rows.map(r => <tr key={r.id}><td><Link href={`/rides?${new URLSearchParams({ ...(p.status ? { status: p.status } : {}), ride: r.id })}`}><strong>#{shortId(r.id)}</strong></Link><Status value={r.status} /></td><td><strong>{r.pickup_area || "Unknown"} → {r.destination_area || "Unknown"}</strong><small>{r.is_scheduled ? `Pickup ${dateTime(r.scheduled_pickup_at)}` : "Instant request"}</small></td><td>{r.booking_mode?.replaceAll("_", " ") || "standard"}</td><td>{r.driver_name || "Unassigned"}</td><td>{euros(r.final_fare ?? r.offered_fare, r.currency || "EUR")}</td><td><Status value={r.payment_status || r.payment_method} /></td><td>{dateTime(r.created_at)}</td></tr>)}</tbody></table></div>}
    </Section>
  </>;
}
