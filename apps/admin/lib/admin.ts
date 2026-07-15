import "server-only";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

export type AdminSession = {
  id: string;
  user_id: string;
  email: string;
  full_name: string;
  role: "admin" | "super_admin";
  permissions: string[];
  aal: "aal1" | "aal2";
  mfa_required_for_commands: boolean;
};

export async function requireAdmin(options: { requireAal2?: boolean } = {}) {
  const supabase = await createClient();
  const { data: { user }, error: userError } = await supabase.auth.getUser();
  if (userError || !user) redirect("/login");
  const { data, error } = await supabase.rpc("fn_admin_os_session");
  if (error || !data) redirect("/login?error=not_authorized");
  const session = data as AdminSession;
  if (options.requireAal2 && session.aal !== "aal2") redirect("/mfa");
  return { supabase, session, user };
}

export async function adminRpc<T>(name: string, args?: Record<string, unknown>): Promise<T> {
  const { supabase } = await requireAdmin();
  const { data, error } = await supabase.rpc(name, args);
  if (error) throw new Error(`${name}: ${error.message}`);
  return data as T;
}
