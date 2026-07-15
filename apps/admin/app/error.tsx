"use client";
export default function ErrorPage({ reset }: { reset: () => void }) {
  return <main className="center-state"><div className="error-mark">!</div><h1>We couldn’t load this view</h1><p>No changes were made. Retry or check the audit and service status.</p><button className="button" onClick={reset}>Try again</button></main>;
}
