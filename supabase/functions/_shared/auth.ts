import {
  createClient,
  SupabaseClient,
  User,
} from "jsr:@supabase/supabase-js@2";

export function json(body: Record<string, unknown>, status = 200): Response {
  return Response.json(body, {
    status,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers":
        "authorization, apikey, content-type, x-client-info",
    },
  });
}

export function corsOptions(): Response {
  return new Response(null, {
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      "Access-Control-Allow-Headers":
        "authorization, apikey, content-type, x-client-info",
    },
  });
}

function requiredEnv(name: string): string {
  const value = (Deno.env.get(name) ?? "").trim();
  if (!value) throw new Error(`missing_${name.toLowerCase()}`);
  return value;
}

export function serviceClient(): SupabaseClient {
  return createClient(
    requiredEnv("SUPABASE_URL"),
    requiredEnv("SUPABASE_SERVICE_ROLE_KEY"),
    { auth: { persistSession: false, autoRefreshToken: false } },
  );
}

export async function authenticatedUser(
  req: Request,
): Promise<User | Response> {
  const authorization = req.headers.get("Authorization") ?? "";
  if (!authorization.startsWith("Bearer ")) {
    return json({ ok: false, error: "unauthorized" }, 401);
  }

  const client = createClient(
    requiredEnv("SUPABASE_URL"),
    requiredEnv("SUPABASE_ANON_KEY"),
    {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false, autoRefreshToken: false },
    },
  );
  const { data, error } = await client.auth.getUser();
  if (error || !data.user) {
    return json({ ok: false, error: "unauthorized" }, 401);
  }
  return data.user;
}

export async function authenticatedDriver(
  req: Request,
): Promise<{ user: User; driverId: string } | Response> {
  const user = await authenticatedUser(req);
  if (user instanceof Response) return user;

  const { data, error } = await serviceClient()
    .from("drivers")
    .select("id")
    .eq("user_id", user.id)
    .maybeSingle();
  if (error || !data?.id) {
    return json({ ok: false, error: "not_a_driver" }, 403);
  }
  return { user, driverId: data.id as string };
}

export async function authenticatedAdmin(
  req: Request,
): Promise<User | Response> {
  const user = await authenticatedUser(req);
  if (user instanceof Response) return user;

  const role = user.app_metadata?.role;
  if (role !== "admin" && role !== "super_admin") {
    return json({ ok: false, error: "not_authorized" }, 403);
  }
  return user;
}

export function isUuid(value: unknown): value is string {
  return typeof value === "string" &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
      .test(value);
}
