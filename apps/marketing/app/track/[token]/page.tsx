import type { Metadata } from "next";

import { SharedRideTracker } from "./shared-ride-tracker";

export const metadata: Metadata = {
  title: "Live rit volgen",
  description: "Volg een gedeelde HeyCaby-rit live.",
  robots: { index: false, follow: false, noarchive: true },
  referrer: "no-referrer",
};

export default async function SharedRidePage({
  params,
}: {
  params: Promise<{ token: string }>;
}) {
  const { token } = await params;
  return <SharedRideTracker token={token} />;
}
