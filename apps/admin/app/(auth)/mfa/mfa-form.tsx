"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

type Factor = { id: string; status: string; friendly_name?: string };

export function MfaForm() {
  const router = useRouter();
  const [factor, setFactor] = useState<Factor | null>(null);
  const [qr, setQr] = useState("");
  const [code, setCode] = useState("");
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  useEffect(() => { void (async () => {
    const supabase = createClient();
    const { data } = await supabase.auth.mfa.listFactors();
    const verified = data?.totp?.find((item: Factor) => item.status === "verified");
    if (verified) { setFactor(verified); return; }
    const { data: enrolled, error } = await supabase.auth.mfa.enroll({ factorType: "totp", friendlyName: "HeyCaby Admin OS" });
    if (error || !enrolled) { setError("Could not prepare multi-factor authentication."); return; }
    setFactor(enrolled); setQr(enrolled.totp.qr_code);
  })(); }, []);

  async function verify(event: React.FormEvent) {
    event.preventDefault(); if (!factor) return; setBusy(true); setError("");
    const supabase = createClient();
    const { data: challenged, error: challengeError } = await supabase.auth.mfa.challenge({ factorId: factor.id });
    if (challengeError || !challenged) { setBusy(false); setError("Could not start verification."); return; }
    const { error } = await supabase.auth.mfa.verify({ factorId: factor.id, challengeId: challenged.id, code });
    setBusy(false);
    if (error) { setError("That code was not accepted. Try the newest code."); return; }
    router.replace("/overview"); router.refresh();
  }
  return <form className="auth-card" onSubmit={verify}>
    <div><span className="eyebrow">Step-up security</span><h1>Verify it’s you</h1><p>Sensitive commands require a current authenticator code.</p></div>
    {qr && <div className="qr"><img src={qr} alt="Authenticator QR code"/><p>Scan once with your authenticator app, then enter its six-digit code.</p></div>}
    <label><span>Authenticator code</span><input className="input" value={code} onChange={(e)=>setCode(e.target.value.replace(/\D/g,"").slice(0,6))} inputMode="numeric" autoComplete="one-time-code" pattern="[0-9]{6}" required /></label>
    {error && <p className="form-error" role="alert">{error}</p>}
    <button className="button button-full" disabled={busy || !factor || code.length !== 6}>{busy ? "Checking…" : "Verify and continue"}</button>
  </form>;
}
