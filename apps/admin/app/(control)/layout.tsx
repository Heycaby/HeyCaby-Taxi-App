import { AppShell } from "@/components/app-shell";
import { requireAdmin } from "@/lib/admin";

export default async function ControlLayout({ children }: { children: React.ReactNode }) {
  const { session } = await requireAdmin();
  return <AppShell session={session}>{children}</AppShell>;
}
