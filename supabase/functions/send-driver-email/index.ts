import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { authenticatedAdmin } from "../_shared/auth.ts";

type EmailType =
  | "welcome"
  | "standard_welcome"
  | "verification_passed"
  | "post_launch_referral";
interface EmailRequest {
  mode?: "send" | "dispatch_queued";
  driver_id?: string;
  founding_signup_id?: string;
  email_type?: EmailType;
  template_data?: Record<string, unknown>;
}

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  "";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function escapeHtml(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function firstName(fullName: string, email: string): string {
  const trimmed = (fullName || "").trim();
  if (trimmed) return trimmed.split(/\s+/)[0];
  return (email.split("@")[0] || "chauffeur").trim() || "chauffeur";
}

function safeTemplateType(raw: string | null | undefined): EmailType | null {
  const v = (raw || "").trim();
  if (
    v === "welcome" || v === "standard_welcome" ||
    v === "verification_passed" || v === "post_launch_referral"
  ) return v;
  return null;
}

function isFounding(n: number | null): boolean {
  return typeof n === "number" && n > 0 && n <= 200;
}

function htmlWelcomeFounding(
  name: string,
  number: number,
  verificationUrl: string,
): string {
  return `<!doctype html><html><body style="font-family:Inter,Arial,sans-serif;color:#111;line-height:1.5;padding:24px;">
  <h1 style="margin:0 0 12px;font-size:32px;">Hey<span style="color:#E4A900;">Caby</span></h1>
  <p style="font-size:30px;font-weight:700;">Founding Member #${number} ${
    escapeHtml(name)
  } 👋 Welkom bij HeyCaby. Je bent één van de eerste chauffeurs die ons platform vormgeeft.</p>
  <h2 style="font-size:34px;margin:20px 0 8px;">Actie vereist</h2>
  <p style="font-size:34px;color:#555;">Je plek is voorlopig. Verifieer je rijbewijs om definitief ingeschreven te blijven.</p>
  <a href="${
    escapeHtml(verificationUrl)
  }" style="display:inline-block;background:#E4A900;color:#111;text-decoration:none;font-weight:700;font-size:32px;padding:14px 28px;border-radius:12px;">Verifieer nu</a>
  <p style="font-size:32px;color:#666;margin-top:18px;">Na goedkeuring: volledige toegang bij lancering.</p>
  <p style="font-size:38px;">HeyCaby Team</p>
  </body></html>`;
}

function htmlWelcomeStandard(name: string, verificationUrl: string): string {
  return `<!doctype html><html><body style="font-family:Inter,Arial,sans-serif;color:#111;line-height:1.5;padding:24px;">
  <h1 style="margin:0 0 12px;font-size:32px;">Hey<span style="color:#E4A900;">Caby</span></h1>
  <p style="font-size:36px;">Welkom, ${
    escapeHtml(name)
  } 👋 Je bent aangemeld als chauffeur bij HeyCaby.</p>
  <h2 style="font-size:38px;margin:20px 0 8px;">Volgende stap</h2>
  <p style="font-size:34px;color:#555;">Verifieer je rijbewijs om online te gaan.</p>
  <a href="${
    escapeHtml(verificationUrl)
  }" style="display:inline-block;background:#E4A900;color:#111;text-decoration:none;font-weight:700;font-size:34px;padding:14px 28px;border-radius:12px;">Start verificatie</a>
  <p style="font-size:32px;color:#666;margin-top:18px;">Na goedkeuring: volledige toegang tot het platform.</p>
  <p style="font-size:38px;">HeyCaby Team</p>
  </body></html>`;
}

function htmlVerificationPassed(
  name: string,
  contractUrl: string,
  contractRef: string | null,
): string {
  return `<!doctype html><html><body style="font-family:Inter,Arial,sans-serif;color:#111;line-height:1.5;padding:24px;">
  <h1 style="margin:0 0 12px;font-size:32px;">Hey<span style="color:#E4A900;">Caby</span></h1>
  <p style="font-size:34px;font-weight:700;">Je rijbewijs is geverifieerd 🎉</p>
  <p style="font-size:36px;">Gefeliciteerd, ${
    escapeHtml(name)
  }! 🎉 Je rijbewijs is geverifieerd. Je bent klaar om te rijden bij HeyCaby.</p>
  <h2 style="font-size:34px;margin:20px 0 8px;">Onze belofte aan jou</h2>
  <p style="font-size:34px;color:#555;">Lees hoe we samenwerken — eerlijke voorwaarden, geen verrassingen.</p>
  <a href="${
    escapeHtml(contractUrl)
  }" style="display:inline-block;background:#E4A900;color:#111;text-decoration:none;font-weight:700;font-size:32px;padding:14px 28px;border-radius:12px;">Bekijk onze afspraak</a>
  <p style="font-size:30px;color:#666;margin-top:18px;">Contractreferentie: ${
    escapeHtml(contractRef || "n/a")
  }</p>
  <p style="font-size:34px;">Vragen? Chat met onze AI-support in de app of mail naar contact@heycaby.nl</p>
  <p style="font-size:38px;">HeyCaby Team</p>
  </body></html>`;
}

function htmlGrowthShare(name: string, number: number | null): string {
  const badge = isFounding(number) ? `Founding Member #${number}` : "Chauffeur";
  return `<!doctype html><html><body style="font-family:Inter,Arial,sans-serif;color:#111;line-height:1.5;padding:24px;">
  <h1 style="margin:0 0 12px;font-size:32px;">Hey<span style="color:#E4A900;">Caby</span></h1>
  <div style="display:inline-block;background:#E4A900;color:#111;font-weight:800;font-size:34px;padding:14px 22px;border-radius:12px;margin:8px 0 18px;">${
    escapeHtml(badge)
  }</div>
  <p style="font-size:36px;">Welkom in de familie, ${
    escapeHtml(name)
  } 👋 Jij bouwt mee aan de toekomst van HeyCaby.</p>
  <h2 style="font-size:34px;margin:20px 0 8px;">Jouw missie</h2>
  <p style="font-size:34px;color:#555;">Vertel elke passagier over HeyCaby. 200 chauffeurs x 5 ritten per dag = 1000 nieuwe gebruikers. Jij maakt het verschil.</p>
  <a href="https://www.heycaby.nl/chauffeur" style="display:inline-block;background:#E4A900;color:#111;text-decoration:none;font-weight:700;font-size:32px;padding:14px 28px;border-radius:12px;">Start met rijden</a>
  <p style="font-size:34px;color:#666;margin-top:18px;">Dit platform groeit door jou. Dank dat je erbij bent.</p>
  <p style="font-size:38px;">HeyCaby Team</p>
  </body></html>`;
}

async function sendViaResend(
  args: {
    from: string;
    replyTo: string;
    to: string;
    subject: string;
    html: string;
    text: string;
  },
): Promise<{ ok: boolean; data: any }> {
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${RESEND_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: args.from,
      to: [args.to],
      reply_to: args.replyTo,
      subject: args.subject,
      html: args.html,
      text: args.text,
    }),
  });
  const data = await res.json();
  return { ok: res.ok, data };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (req.method !== "POST") {
      return new Response(
        JSON.stringify({ success: false, message: "method_not_allowed" }),
        {
          status: 405,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const actor = await authenticatedAdmin(req);
    if (actor instanceof Response) return actor;

    if (!RESEND_API_KEY || !SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
      return new Response(
        JSON.stringify({ success: false, message: "missing_function_env" }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const body: EmailRequest = await req.json();
    const mode = body.mode ?? "send";
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    if (mode === "dispatch_queued") {
      const { data: queued } = await supabase
        .from("driver_email_events")
        .select("id,driver_id,founding_signup_id,email_type,metadata")
        .eq("status", "queued")
        .eq("email_type", "post_launch_referral")
        .lte("created_at", new Date(Date.now() - 60 * 60 * 1000).toISOString())
        .limit(50);

      let sent = 0;
      for (const q of queued ?? []) {
        const r = await fetch(req.url, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: req.headers.get("Authorization") ?? "",
          },
          body: JSON.stringify({
            mode: "send",
            driver_id: q.driver_id,
            founding_signup_id: q.founding_signup_id,
            email_type: "post_launch_referral",
            template_data: q.metadata || {},
          }),
        });
        const d = await r.json();
        if (d?.success) {
          await supabase.from("driver_email_events").update({
            status: "sent",
            sent_at: new Date().toISOString(),
          }).eq("id", q.id);
          sent += 1;
        } else {
          await supabase.from("driver_email_events").update({
            status: "failed",
            error_message: JSON.stringify(d),
          }).eq("id", q.id);
        }
      }

      return new Response(
        JSON.stringify({ success: true, mode, dispatched: sent }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    if (!body.driver_id && !body.founding_signup_id) {
      return new Response(
        JSON.stringify({
          success: false,
          message: "driver_id_or_founding_signup_id_required",
        }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    let driverId: string | null = body.driver_id ?? null;
    let signupId: string | null = body.founding_signup_id ?? null;
    let email = "";
    let fullName = "";
    let number: number | null = null;
    let veriffUrl = "";

    if (signupId) {
      const { data: s, error } = await supabase
        .from("founding_driver_signups")
        .select(
          "id,driver_id,email,full_name,founding_number,veriff_session_url",
        )
        .eq("id", signupId)
        .single();
      if (error || !s) {
        return new Response(
          JSON.stringify({
            success: false,
            message: "founding_signup_not_found",
          }),
          {
            status: 404,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          },
        );
      }
      driverId = s.driver_id ?? driverId;
      email = (s.email ?? "").trim().toLowerCase();
      fullName = (s.full_name ?? "").trim();
      number = typeof s.founding_number === "number" ? s.founding_number : null;
      veriffUrl = (s.veriff_session_url ?? "").trim();
    }

    if (driverId && !email) {
      const { data: d, error } = await supabase
        .from("drivers")
        .select("id,email,full_name,founding_number")
        .eq("id", driverId)
        .single();
      if (error || !d) {
        return new Response(
          JSON.stringify({ success: false, message: "driver_not_found" }),
          {
            status: 404,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          },
        );
      }
      email = (d.email ?? "").trim().toLowerCase();
      fullName = fullName || (d.full_name ?? "").trim();
      number = number ??
        (typeof d.founding_number === "number" ? d.founding_number : null);
      if (!signupId && email) {
        const { data: s2 } = await supabase
          .from("founding_driver_signups")
          .select("id,veriff_session_url,founding_number")
          .eq("email", email)
          .order("updated_at", { ascending: false })
          .limit(1)
          .maybeSingle();
        if (s2) {
          signupId = s2.id ?? signupId;
          number = typeof s2.founding_number === "number"
            ? s2.founding_number
            : number;
          veriffUrl = veriffUrl || (s2.veriff_session_url ?? "").trim();
        }
      }
    }

    if (!email) {
      return new Response(
        JSON.stringify({ success: false, message: "recipient_email_missing" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    let emailType: EmailType;
    if (body.email_type) {
      const forced = safeTemplateType(body.email_type);
      if (!forced) {
        return new Response(
          JSON.stringify({ success: false, message: "unsupported_email_type" }),
          {
            status: 400,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          },
        );
      }
      emailType = forced;
    } else {
      emailType = isFounding(number) ? "welcome" : "standard_welcome";
    }

    const fname = firstName(fullName, email);
    const verificationUrl =
      ((body.template_data?.veriff_url as string | undefined) ?? "").trim() ||
      ((body.template_data?.verification_url as string | undefined) ?? "")
        .trim() ||
      ((body.template_data?.cta_url as string | undefined) ?? "").trim() ||
      veriffUrl ||
      "https://www.heycaby.nl/chauffeur";

    const from = isFounding(number)
      ? "HeyCaby <heycaby@heycaby.nl>"
      : "HeyCaby <hello@heycaby.nl>";
    const replyTo = "contact@heycaby.nl";

    const dedupeCol = driverId ? "driver_id" : "founding_signup_id";
    const dedupeVal = driverId ?? signupId;
    if (dedupeVal && emailType !== "post_launch_referral") {
      const { data: ex } = await supabase
        .from("driver_email_events")
        .select("id")
        .eq(dedupeCol, dedupeVal)
        .eq("email_type", emailType)
        .eq("status", "sent")
        .limit(1)
        .maybeSingle();
      if (ex?.id) {
        return new Response(
          JSON.stringify({
            success: true,
            skipped: true,
            message: "already_sent",
          }),
          {
            status: 200,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          },
        );
      }
    }

    const contractRefRaw =
      ((body.template_data?.contract_ref as string | undefined) ?? "").trim();
    const contractRef: string | null = contractRefRaw || null;
    let contractUrl =
      ((body.template_data?.contract_url as string | undefined) ?? "").trim();
    contractUrl = contractUrl ||
      "https://www.heycaby.nl/chauffeur/founding-member-contract";

    let subject = "Welkom bij HeyCaby";
    let html = "";
    let text = "";

    if (emailType === "welcome") {
      html = htmlWelcomeFounding(fname, number ?? 0, verificationUrl);
      text = `Founding Member #${
        number ?? ""
      } ${fname} - Welkom bij HeyCaby. Verifieer je rijbewijs: ${verificationUrl}`;
    } else if (emailType === "standard_welcome") {
      html = htmlWelcomeStandard(fname, verificationUrl);
      text =
        `Welkom ${fname}. Verifieer je rijbewijs om online te gaan: ${verificationUrl}`;
    } else if (emailType === "verification_passed") {
      subject = "Je rijbewijs is geverifieerd 🎉";
      html = htmlVerificationPassed(fname, contractUrl, contractRef);
      text =
        `Gefeliciteerd ${fname}. Je rijbewijs is geverifieerd. Bekijk je contract: ${contractUrl}`;
    } else {
      subject = "Welkom in de familie — jij bouwt HeyCaby mee";
      html = htmlGrowthShare(fname, number);
      text =
        `Welkom ${fname}. Vertel passagiers over HeyCaby en help ons groeien.`;
    }

    const resend = await sendViaResend({
      from,
      replyTo,
      to: email,
      subject,
      html,
      text,
    });

    const { data: ev } = await supabase
      .from("driver_email_events")
      .insert({
        driver_id: driverId,
        founding_signup_id: signupId,
        email_type: emailType,
        status: resend.ok ? "sent" : "failed",
        sent_at: resend.ok ? new Date().toISOString() : null,
        error_message: resend.ok ? null : JSON.stringify(resend.data),
        retry_count: 0,
        metadata: {
          provider: "resend",
          resend_id: resend.data?.id ?? null,
          first_name: fname,
          founding_number: number,
          verification_url: verificationUrl,
          contract_url: contractUrl,
          contract_ref: contractRef,
          from,
          reply_to: replyTo,
          subject,
        },
      })
      .select("id")
      .single();

    if (!resend.ok) {
      return new Response(
        JSON.stringify({
          success: false,
          message: "resend_failed",
          detail: resend.data,
          email_event_id: ev?.id ?? null,
        }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    if (emailType === "verification_passed") {
      const keyVal = driverId ?? signupId;
      if (keyVal) {
        const { data: exQ } = await supabase
          .from("driver_email_events")
          .select("id")
          .eq(dedupeCol, keyVal)
          .eq("email_type", "post_launch_referral")
          .in("status", ["queued", "sent"])
          .limit(1)
          .maybeSingle();

        if (!exQ?.id) {
          await supabase.from("driver_email_events").insert({
            driver_id: driverId,
            founding_signup_id: signupId,
            email_type: "post_launch_referral",
            status: "queued",
            retry_count: 0,
            metadata: {
              queued_at: new Date().toISOString(),
              send_after_minutes: 60,
              from,
              reply_to: replyTo,
              first_name: fname,
              founding_number: number,
            },
          });
        }
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: "sent",
        email_event_id: ev?.id ?? null,
        email_type: emailType,
        recipient: email,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (error) {
    return new Response(
      JSON.stringify({
        success: false,
        message: "internal_error",
        error: error instanceof Error ? error.message : String(error),
      }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});
