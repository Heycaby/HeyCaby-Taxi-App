import type { Metadata } from "next";
import { adminRpc } from "@/lib/admin";
import { dateTime, shortId } from "@/lib/format";
import { Empty, PageHeader, Section } from "@/components/ui";
export const metadata:Metadata={title:"Audit trail"};
type Audit={id:string;action:string;resource_type:string;resource_id:string;details:Record<string,unknown>;created_at:string;admin_name:string;admin_email:string};
export default async function AuditPage(){const rows=await adminRpc<Audit[]>("fn_admin_os_audit_log",{p_limit:250});return <><PageHeader eyebrow="Evidence layer" title="Audit trail" description="Append-only operational accountability for sensitive access, communications, restrictions, and case decisions."/><Section title="Administrator activity" description="Latest 250 events">{rows.length===0?<Empty title="No activity recorded" body="Protected Admin actions will appear here."/>:<div className="audit-list">{rows.map(a=><article key={a.id}><span className="audit-icon">{a.action.slice(0,1).toUpperCase()}</span><div><strong>{a.action.replaceAll("."," · ").replaceAll("_"," ")}</strong><p>{a.resource_type} #{shortId(a.resource_id)} · by {a.admin_name||a.admin_email||"administrator"}</p><details><summary>Event details</summary><pre>{JSON.stringify(a.details,null,2)}</pre></details></div><time>{dateTime(a.created_at)}</time></article>)}</div>}</Section></>}
