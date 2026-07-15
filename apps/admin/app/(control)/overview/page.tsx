import type { Metadata } from "next";
import Link from "next/link";
import { AlertTriangle, ArrowRight, CarFront, Clock3, Headphones, ShieldAlert } from "lucide-react";
import { adminRpc } from "@/lib/admin";
import { euros, integer, money } from "@/lib/format";
import { PageHeader, Section, StatCard } from "@/components/ui";

export const metadata: Metadata = { title: "Overview" };
type Overview = { generated_at:string; drivers:{total:number;available:number;on_ride:number;on_break:number;offline:number;verified:number;restricted:number}; rides:{total:number;today:number;active:number;completed_today:number;cancelled_today:number}; operations:{open_support:number;urgent_support:number;open_reports:number;active_payment_alerts:number}; finance:{platform_commission_cents:number;completed_ride_value_eur:number;prepaid_volume_cents:number;outstanding_platform_balance_cents:number} };

export default async function OverviewPage() {
  const data = await adminRpc<Overview>("fn_admin_os_overview");
  const driverParts = [data.drivers.available,data.drivers.on_ride,data.drivers.on_break,data.drivers.offline];
  const maxDrivers = Math.max(data.drivers.total,1);
  return <>
    <PageHeader eyebrow="Live command centre" title="Good morning. Here’s HeyCaby now." description="One privacy-safe view of supply, rides, support, safety, and money from the production source of truth." action={<span className="freshness"><i/>Updated live</span>}/>
    <div className="stats-grid">
      <StatCard label="Drivers online" value={integer(data.drivers.available + data.drivers.on_ride)} note={`${data.drivers.on_ride} currently on a ride`} tone="green"/>
      <StatCard label="Rides today" value={integer(data.rides.today)} note={`${data.rides.active} active · ${data.rides.completed_today} completed`}/>
      <StatCard label="Platform commission" value={money(data.finance.platform_commission_cents)} note="Completed rides, all time" tone="green"/>
      <StatCard label="Needs attention" value={integer(data.operations.urgent_support + data.operations.active_payment_alerts)} note="Urgent support + payment alerts" tone={data.operations.urgent_support+data.operations.active_payment_alerts>0?"red":"default"}/>
    </div>
    <div className="dashboard-grid">
      <Section title="Driver network" description={`${data.drivers.total} registered drivers`} action={<Link className="text-link" href="/drivers">Open directory <ArrowRight size={15}/></Link>}>
        <div className="driver-supply"><div className="supply-ring" style={{"--available":`${data.drivers.available/maxDrivers*360}deg`} as React.CSSProperties}><strong>{data.drivers.available}</strong><span>available</span></div><div className="supply-list">{[["Available",data.drivers.available,"green"],["On ride",data.drivers.on_ride,"blue"],["On break",data.drivers.on_break,"amber"],["Offline",data.drivers.offline,"grey"]].map(([label,value,color])=><div key={String(label)}><i className={`dot-${color}`}/><span>{label}</span><strong>{value}</strong></div>)}</div></div>
        <div className="segmented-bar">{driverParts.map((value,index)=><i key={index} style={{width:`${Number(value)/maxDrivers*100}%`}}/>)}</div>
      </Section>
      <Section title="Operational inbox" description="Queues requiring human judgment">
        <div className="inbox-list">
          <Link href="/support"><Headphones/><span><strong>{data.operations.open_support} open support cases</strong><small>{data.operations.urgent_support} high or urgent</small></span><ArrowRight/></Link>
          <Link href="/reports"><ShieldAlert/><span><strong>{data.operations.open_reports} unresolved reports</strong><small>Safety and ride reports</small></span><ArrowRight/></Link>
          <Link href="/payments"><AlertTriangle/><span><strong>{data.operations.active_payment_alerts} payment alerts</strong><small>Mollie lifecycle monitoring</small></span><ArrowRight/></Link>
          <Link href="/rides"><Clock3/><span><strong>{data.rides.active} active rides</strong><small>Canonical lifecycle state</small></span><ArrowRight/></Link>
        </div>
      </Section>
      <Section title="Marketplace money" description="Backend-derived totals, never browser-calculated">
        <div className="money-grid"><div><span>Completed ride value</span><strong>{euros(data.finance.completed_ride_value_eur)}</strong></div><div><span>Prepaid volume</span><strong>{money(data.finance.prepaid_volume_cents)}</strong></div><div><span>Platform Balance due</span><strong>{money(data.finance.outstanding_platform_balance_cents)}</strong></div><div><span>Commission</span><strong>{money(data.finance.platform_commission_cents)}</strong></div></div>
      </Section>
      <Section title="System contract" description="How Admin OS stays safe">
        <div className="contract-list"><div><CarFront/><span><strong>Ride state</strong><small>Canonical ride RPCs and database state</small></span></div><div><ShieldAlert/><span><strong>Protected commands</strong><small>MFA, role permission, mandatory reason, audit event</small></span></div><div><Clock3/><span><strong>Privacy</strong><small>Masked lists; sensitive detail access is reason-gated</small></span></div></div>
      </Section>
    </div>
  </>;
}
