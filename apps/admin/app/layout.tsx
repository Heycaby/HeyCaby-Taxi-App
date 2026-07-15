import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: { default: "HeyCaby Admin OS", template: "%s · HeyCaby Admin OS" },
  description: "Secure operational control plane for HeyCaby.",
  robots: { index: false, follow: false, nocache: true }
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="en"><body>{children}</body></html>;
}
