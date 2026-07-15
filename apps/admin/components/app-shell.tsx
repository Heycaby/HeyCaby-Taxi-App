"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useState } from "react";
import {
  Activity, BarChart3, BellRing, Bot, CarFront, ClipboardCheck, CreditCard,
  FileWarning, Headphones, LayoutDashboard, LogOut, Menu, Settings, ShieldCheck, X
} from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import type { AdminSession } from "@/lib/admin";

const sections = [
  { label: "Command", links: [
    ["/overview", "Overview", LayoutDashboard], ["/drivers", "Drivers", CarFront], ["/rides", "Rides", Activity]
  ]},
  { label: "Operations", links: [
    ["/support", "Support", Headphones], ["/reports", "Reports", FileWarning], ["/communications", "Communications", BellRing]
  ]},
  { label: "Money", links: [
    ["/finance", "Finance", BarChart3], ["/payments", "Payments", CreditCard]
  ]},
  { label: "Control", links: [
    ["/assistant", "Admin AI", Bot], ["/audit", "Audit trail", ClipboardCheck], ["/settings", "Settings", Settings]
  ]}
] as const;

export function AppShell({ session, children }: { session: AdminSession; children: React.ReactNode }) {
  const path = usePathname(); const router = useRouter(); const [open, setOpen] = useState(false);
  async function signOut() { await createClient().auth.signOut(); router.replace("/login"); router.refresh(); }
  return <div className="app-frame">
    <aside className={`sidebar ${open ? "sidebar-open" : ""}`}>
      <div className="sidebar-head"><Link href="/overview" className="brand"><span className="brand-mark">H</span><span><b>HeyCaby</b><small>Admin OS</small></span></Link><button className="icon-button mobile-only" onClick={()=>setOpen(false)} aria-label="Close navigation"><X/></button></div>
      <nav>{sections.map((section)=><div className="nav-section" key={section.label}><span>{section.label}</span>{section.links.map(([href,label,Icon])=><Link key={href} href={href} onClick={()=>setOpen(false)} className={path===href ? "active" : ""}><Icon size={18}/>{label}</Link>)}</div>)}</nav>
      <div className="sidebar-foot"><div className="secure-chip"><ShieldCheck size={16}/><span>Production · Secure</span></div><button onClick={signOut}><LogOut size={17}/>Sign out</button></div>
    </aside>
    <div className="workspace">
      <header className="topbar"><button className="icon-button mobile-only" onClick={()=>setOpen(true)} aria-label="Open navigation"><Menu/></button><div className="topbar-status"><span className="live-dot"/>Connected to production truth</div><div className="admin-identity"><div><strong>{session.full_name || session.email}</strong><small>{session.role.replace("_"," ")} · {session.aal.toUpperCase()}</small></div><span>{(session.full_name || session.email).slice(0,2).toUpperCase()}</span></div></header>
      <div className="content">{children}</div>
    </div>
  </div>;
}
