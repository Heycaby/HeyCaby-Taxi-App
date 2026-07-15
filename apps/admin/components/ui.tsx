import { ArrowDownRight, ArrowUpRight, Minus } from "lucide-react";

export function PageHeader({ eyebrow, title, description, action }: { eyebrow: string; title: string; description: string; action?: React.ReactNode }) {
  return <div className="page-header"><div><span className="eyebrow">{eyebrow}</span><h1>{title}</h1><p>{description}</p></div>{action}</div>;
}

export function StatCard({ label, value, note, tone="default", trend }: { label:string; value:string; note:string; tone?:"default"|"green"|"amber"|"red"; trend?:number }) {
  const Icon = trend === undefined || trend === 0 ? Minus : trend > 0 ? ArrowUpRight : ArrowDownRight;
  return <article className={`stat-card tone-${tone}`}><div><span>{label}</span>{trend !== undefined && <small className={trend >= 0 ? "positive" : "negative"}><Icon size={13}/>{Math.abs(trend)}%</small>}</div><strong>{value}</strong><p>{note}</p></article>;
}

export function Status({ value }: { value?: string | null }) {
  const normalized = (value || "unknown").toLowerCase();
  const good = ["active","available","verified","compliant","completed","paid","routed","resolved"];
  const bad = ["suspended","restricted","failed","cancelled","urgent","overdue"];
  return <span className={`status ${good.includes(normalized)?"status-good":bad.includes(normalized)?"status-bad":"status-neutral"}`}><i/>{normalized.replaceAll("_"," ")}</span>;
}

export function Empty({ title, body }: { title: string; body: string }) { return <div className="empty"><span>✓</span><h3>{title}</h3><p>{body}</p></div>; }

export function Section({ title, description, children, action }: { title:string; description?:string; children:React.ReactNode; action?:React.ReactNode }) {
  return <section className="panel"><header><div><h2>{title}</h2>{description&&<p>{description}</p>}</div>{action}</header>{children}</section>;
}
