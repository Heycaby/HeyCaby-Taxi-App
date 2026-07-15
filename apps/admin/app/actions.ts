"use server";

import { revalidatePath } from "next/cache";
import { requireAdmin } from "@/lib/admin";

const text = (form: FormData, key: string, max = 1000) => String(form.get(key) || "").trim().slice(0, max);

export async function resolveTicket(form: FormData) {
  const { supabase } = await requireAdmin({ requireAal2: true });
  const { error } = await supabase.rpc("fn_admin_os_resolve_ticket", {
    p_ticket_id: text(form,"ticket_id",36), p_outcome: text(form,"outcome",100), p_summary: text(form,"summary")
  });
  if (error) throw new Error(error.message); revalidatePath("/support"); revalidatePath("/overview");
}

export async function resolveReport(form: FormData) {
  const { supabase } = await requireAdmin({ requireAal2: true });
  const { error } = await supabase.rpc("fn_admin_os_resolve_report", {
    p_report_id: text(form,"report_id",36), p_response: text(form,"response")
  });
  if (error) throw new Error(error.message); revalidatePath("/reports"); revalidatePath("/overview");
}

export async function setDriverRestriction(form: FormData) {
  const { supabase } = await requireAdmin({ requireAal2: true });
  const { error } = await supabase.rpc("fn_admin_os_set_driver_restriction", {
    p_driver_id: text(form,"driver_id",36), p_restricted: text(form,"restricted",8)==="true",
    p_reason: text(form,"reason"), p_expires_at: text(form,"expires_at",40)||null
  });
  if (error) throw new Error(error.message); revalidatePath("/drivers"); revalidatePath("/overview");
}

export async function sendPush(form: FormData) {
  const { supabase } = await requireAdmin({ requireAal2: true });
  const target=text(form,"target",20), title=text(form,"title",120), body=text(form,"body",500);
  if (!["all","riders","drivers"].includes(target)) throw new Error("Invalid push target");
  const { data, error } = await supabase.functions.invoke("send-push", { body: {
    target, notification: { title, body, tag: `admin-${Date.now()}`, url: "/" }
  }});
  const result = error ? { ok:false, error:error.message } : (data ?? {ok:true});
  const { error: auditError } = await supabase.rpc("fn_admin_os_log_communication", {
    p_channel:"push",p_target:target,p_title:title,p_body:body,p_result:result
  });
  if (auditError) throw new Error(`Push audit failed: ${auditError.message}`);
  if (error) throw new Error(`Push delivery failed: ${error.message}`);
  revalidatePath("/communications"); revalidatePath("/audit");
}

export async function scheduleDriverServiceFee(form: FormData) {
  const { supabase } = await requireAdmin({ requireAal2: true });
  const feeType = text(form, "fee_type", 20);
  const amountEuros = Number(text(form, "amount_euros", 20));
  const percentage = Number(text(form, "percentage", 20));
  const warningEuros = Number(text(form, "warning_euros", 20));
  const limitEuros = Number(text(form, "limit_euros", 20));
  const effectiveFrom = text(form, "effective_from", 50);
  const reason = text(form, "reason", 1000);
  const cents = (value: number) => Number.isFinite(value) ? Math.round(value * 100) : null;
  if (!["fixed", "percentage"].includes(feeType) || !effectiveFrom || reason.length < 8) {
    throw new Error("Complete the fee type, future effective date, and reason.");
  }
  const { data, error } = await supabase.rpc("fn_admin_schedule_driver_service_fee_change", {
    p_fee_type: feeType,
    p_amount_cents: feeType === "fixed" ? cents(amountEuros) : null,
    p_percentage_basis_points: feeType === "percentage" && Number.isFinite(percentage)
      ? Math.round(percentage * 100)
      : null,
    p_effective_from: new Date(effectiveFrom).toISOString(),
    p_reason: reason,
    p_warning_threshold_cents: cents(warningEuros),
    p_balance_limit_cents: cents(limitEuros),
  });
  if (error) throw new Error(error.message);
  if (data?.ok !== true) throw new Error(data?.error || "Fee change was rejected");
  revalidatePath("/finance"); revalidatePath("/audit");
}

export async function waiveDriverServiceFeeEntry(form: FormData) {
  const { supabase } = await requireAdmin({ requireAal2: true });
  const ledgerId = text(form, "ledger_id", 36);
  const reason = text(form, "reason", 1000);
  if (!ledgerId || reason.length < 8) throw new Error("A detailed waiver reason is required.");
  const { data, error } = await supabase.rpc("fn_admin_waive_driver_balance_entry", {
    p_ledger_id: ledgerId, p_reason: reason,
  });
  if (error) throw new Error(error.message);
  if (data?.ok !== true) throw new Error(data?.error || "Waiver was rejected");
  revalidatePath("/finance"); revalidatePath("/audit"); revalidatePath("/drivers");
}
