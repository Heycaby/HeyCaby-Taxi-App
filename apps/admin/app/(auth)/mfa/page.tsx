import type { Metadata } from "next";
import { requireAdmin } from "@/lib/admin";
import { MfaForm } from "./mfa-form";
export const metadata: Metadata = { title: "Security check" };
export default async function MfaPage() { await requireAdmin(); return <MfaForm />; }
