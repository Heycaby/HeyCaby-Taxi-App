"use client";

import { createBrowserClient } from "@supabase/ssr";
import { publicEnv } from "@/lib/env";

let client: ReturnType<typeof createBrowserClient> | undefined;
export function createClient() {
  const { url, key } = publicEnv();
  client ??= createBrowserClient(url, key);
  return client;
}
