"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { LockKeyhole, Mail } from "lucide-react";
import { createClient } from "@/lib/supabase/client";

export function LoginForm() {
  const router = useRouter();
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  async function submit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault(); setBusy(true); setError("");
    const form = new FormData(event.currentTarget);
    const { error } = await createClient().auth.signInWithPassword({
      email: String(form.get("email") || ""), password: String(form.get("password") || "")
    });
    setBusy(false);
    if (error) { setError("Access could not be verified. Check your credentials."); return; }
    router.replace("/overview"); router.refresh();
  }
  return <form className="auth-card" onSubmit={submit}>
    <div><span className="eyebrow">Secure access</span><h1>Welcome back</h1><p>Sign in with your approved HeyCaby administrator account.</p></div>
    <label><span>Email</span><div className="input-wrap"><Mail size={18}/><input name="email" type="email" autoComplete="username" required /></div></label>
    <label><span>Password</span><div className="input-wrap"><LockKeyhole size={18}/><input name="password" type="password" autoComplete="current-password" required /></div></label>
    {error && <p className="form-error" role="alert">{error}</p>}
    <button className="button button-full" disabled={busy}>{busy ? "Verifying…" : "Continue securely"}</button>
    <p className="form-note">Membership is checked against the production Admin registry after authentication.</p>
  </form>;
}
