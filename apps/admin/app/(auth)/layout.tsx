export default function AuthLayout({ children }: { children: React.ReactNode }) {
  return <main className="auth-shell"><div className="auth-brand"><span className="brand-mark">H</span><div><strong>HeyCaby</strong><small>Admin OS</small></div></div>{children}<p className="auth-foot">Restricted system · Every sensitive action is audited</p></main>;
}
