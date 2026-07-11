/**
 * Shared logic for driver-support-chat and rider-support-chat.
 * Calls OpenRouter chat completions; API key stays in Supabase secrets only.
 */
import { createClient, SupabaseClient } from "jsr:@supabase/supabase-js@2";

const OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions";

export type SupportUserType = "driver" | "rider";

export function json(obj: object, status = 200): Response {
  return new Response(JSON.stringify(obj), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
    },
  });
}

export function corsOptions(): Response {
  return new Response(null, {
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, Authorization, apikey",
    },
  });
}

const DRIVER_SYSTEM =
  `You are Lee, the AI assistant for HeyCaby taxi drivers in the Netherlands. ` +
  `Help with payments, account, rides, compliance, and the driver app. Be concise and accurate. ` +
  `Reply in Dutch when the user writes Dutch; otherwise English. ` +
  `If something needs a human (safety, legal, account takeover, complex disputes), say clearly that the team will review the ticket. ` +
  `Do not invent policy; if unsure, say you are not sure and a human can help.`;

const RIDER_SYSTEM =
  `You are Yaz, the HeyCaby rider customer care assistant powered by ChatGPT 4.0 via OpenRouter. ` +
  `You understand the Rider app deeply and help with rides, payments, booking, account, and support topics. ` +
  `Be concise, practical, and reassuring. Reply in Dutch when the user writes Dutch; otherwise English. ` +
  `Escalate to humans for safety issues or when you cannot verify facts. ` +
  `Do not invent refunds or guarantees.`;

function systemPrompt(userType: SupportUserType): string {
  return userType === "driver" ? DRIVER_SYSTEM : RIDER_SYSTEM;
}

type ChatTurn = { role: "user" | "assistant" | "system"; content: string };

function storedRowToTurn(row: Record<string, unknown>): ChatTurn | null {
  const role = row["role"] as string | undefined;
  const content = (row["content"] as string | undefined)?.trim() ??
    (row["body"] as string | undefined)?.trim();
  if (!content) return null;

  if (role === "user" || role === "assistant" || role === "system") {
    if (role === "system") return null;
    return { role: role as "user" | "assistant", content };
  }

  const sender = row["sender_type"] as string | undefined;
  if (sender === "driver" || sender === "rider") {
    return { role: "user", content };
  }
  return { role: "assistant", content };
}

function buildChatTurnsFromMessages(messages: unknown[]): ChatTurn[] {
  if (!Array.isArray(messages)) return [];
  const out: ChatTurn[] = [];
  for (const raw of messages) {
    if (!raw || typeof raw !== "object") continue;
    const t = storedRowToTurn(raw as Record<string, unknown>);
    if (t) out.push(t);
  }
  return out;
}

function extractOpenRouterText(data: unknown): string {
  if (!data || typeof data !== "object") return "";
  const d = data as Record<string, unknown>;
  const err = d["error"];
  if (err && typeof err === "object") {
    const msg = (err as Record<string, unknown>)["message"];
    if (typeof msg === "string") throw new Error(msg);
  }
  const choices = d["choices"] as unknown[] | undefined;
  const first = choices?.[0] as Record<string, unknown> | undefined;
  const message = first?.["message"] as Record<string, unknown> | undefined;
  const c = message?.["content"];
  if (typeof c === "string" && c.trim()) return c.trim();
  if (Array.isArray(c)) {
    const parts: string[] = [];
    for (const item of c) {
      if (typeof item === "object" && item && "text" in item) {
        const t = (item as Record<string, unknown>)["text"];
        if (typeof t === "string") parts.push(t);
      }
    }
    const joined = parts.join("").trim();
    if (joined) return joined;
  }
  return "";
}

async function callOpenRouter(
  messages: ChatTurn[],
  model: string,
  apiKey: string,
): Promise<{ text: string; model: string }> {
  const siteUrl = Deno.env.get("OPENROUTER_SITE_URL") ??
    Deno.env.get("SUPABASE_URL") ?? "https://heycaby.nl";
  const title = Deno.env.get("OPENROUTER_APP_TITLE") ?? "HeyCaby Support";

  const res = await fetch(OPENROUTER_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${apiKey}`,
      "HTTP-Referer": siteUrl,
      "X-Title": title,
    },
    body: JSON.stringify({
      model,
      messages,
      temperature: 0.4,
      max_tokens: 1024,
    }),
  });

  const rawText = await res.text();
  let parsed: unknown;
  try {
    parsed = JSON.parse(rawText);
  } catch {
    throw new Error(
      `OpenRouter non-JSON (${res.status}): ${rawText.slice(0, 200)}`,
    );
  }

  if (!res.ok) {
    const msg = extractOpenRouterText(parsed) ||
      (typeof parsed === "object" && parsed && "error" in parsed
        ? JSON.stringify((parsed as Record<string, unknown>)["error"])
        : rawText.slice(0, 300));
    throw new Error(`OpenRouter HTTP ${res.status}: ${msg}`);
  }

  const text = extractOpenRouterText(parsed);
  if (!text) throw new Error("OpenRouter returned empty content");
  const responseModel =
    typeof (parsed as Record<string, unknown>)["model"] === "string"
      ? String((parsed as Record<string, unknown>)["model"])
      : model;
  return { text, model: responseModel };
}

async function callOpenRouterWithFallback(
  messages: ChatTurn[],
  configuredModel: string,
  apiKey: string,
): Promise<{ text: string; model: string; usedFallbackModel: boolean }> {
  const candidates = configuredModel === "openrouter/free"
    ? [configuredModel]
    : [configuredModel, "openrouter/free"];
  let lastError: unknown;

  for (const candidate of candidates) {
    try {
      const result = await callOpenRouter(messages, candidate, apiKey);
      return {
        ...result,
        usedFallbackModel: candidate !== configuredModel,
      };
    } catch (error) {
      lastError = error;
      console.error(`OpenRouter model ${candidate}:`, error);
    }
  }

  throw lastError ?? new Error("OpenRouter request failed");
}

function providerUnavailableReply(
  userType: SupportUserType,
  message: string,
): string {
  const isDutch =
    /\b(ik|mijn|rit|chauffeur|betaling|probleem|niet|waarom|hoe|kan|help)\b/i
      .test(message);
  const assistant = userType === "driver" ? "Lee" : "Yaz";
  if (isDutch) {
    return `${assistant} kan nu geen AI-antwoord ophalen. Je bericht is wel veilig opgeslagen voor het supportteam. Probeer het zo opnieuw of neem bij een dringend probleem contact op via support.`;
  }
  return `${assistant} cannot retrieve an AI answer right now. Your message has been safely saved for the support team. Try again shortly or contact support if the issue is urgent.`;
}

async function getUserFromJwt(
  admin: SupabaseClient,
  jwt: string,
): Promise<{ id: string } | null> {
  const { data, error } = await admin.auth.getUser(jwt);
  if (error || !data?.user?.id) return null;
  return { id: data.user.id };
}

async function resolveTicketId(
  admin: SupabaseClient,
  userId: string,
  userType: SupportUserType,
  requestedId: string | undefined,
): Promise<{ ticketId: string } | { error: string; status: number }> {
  const now = new Date();
  const staleCutoff = new Date(now.getTime() - 24 * 60 * 60 * 1000)
    .toISOString();

  // Auto-close inactive ongoing tickets so stale "open" threads do not stick forever.
  const { error: staleErr } = await admin
    .from("tickets")
    .update({
      status: "auto_resolved",
      resolution_summary: "Auto-closed after 24h inactivity.",
      resolution_outcome: "inactivity_timeout",
      updated_at: now.toISOString(),
    })
    .eq("user_id", userId)
    .eq("user_type", userType)
    .in("status", ["open", "in_progress", "awaiting_user"])
    .lt("updated_at", staleCutoff);
  if (staleErr) {
    console.error("resolveTicketId stale close:", staleErr);
  }

  if (requestedId && requestedId.length > 0) {
    const { data: row, error } = await admin
      .from("tickets")
      .select("id, user_id, user_type")
      .eq("id", requestedId)
      .maybeSingle();
    if (error) {
      console.error("resolveTicketId select:", error);
      return { error: "ticket_lookup_failed", status: 500 };
    }
    if (!row) return { error: "ticket_not_found", status: 404 };
    const rowUserId = row.user_id == null ? "" : String(row.user_id);
    const rowType = String(row.user_type ?? "").toLowerCase();
    if (rowUserId !== String(userId) || rowType !== userType) {
      return { error: "forbidden", status: 403 };
    }
    return { ticketId: row.id as string };
  }

  const { data: open, error: openErr } = await admin
    .from("tickets")
    .select("id")
    .eq("user_id", userId)
    .eq("user_type", userType)
    .in("status", ["open", "in_progress", "awaiting_user"])
    .order("updated_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (openErr) {
    console.error("resolveTicketId open list:", openErr);
    return { error: "ticket_lookup_failed", status: 500 };
  }
  if (open?.id) return { ticketId: open.id as string };

  const { data: created, error: insErr } = await admin
    .from("tickets")
    .insert({
      user_id: userId,
      user_type: userType,
      category: "ai_support",
      status: "open",
      messages: [],
    })
    .select("id")
    .single();

  if (insErr || !created?.id) {
    console.error("resolveTicketId insert:", insErr);
    return { error: "ticket_create_failed", status: 500 };
  }
  return { ticketId: created.id as string };
}

export async function handleSupportChatRequest(
  req: Request,
  userType: SupportUserType,
): Promise<Response> {
  if (req.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }

  const apiKey = Deno.env.get("OPENROUTER_API_KEY")?.trim();
  if (!apiKey) {
    console.error("OPENROUTER_API_KEY missing");
  }

  const model = (Deno.env.get("SUPPORT_AI_MODEL") ?? "openrouter/free").trim();

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceKey) {
    return json({ error: "server_misconfigured" }, 500);
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  const jwt = authHeader.replace(/^Bearer\s+/i, "").trim();
  if (!jwt) {
    return json({ error: "missing_authorization" }, 401);
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json() as Record<string, unknown>;
  } catch {
    return json({ error: "invalid_json" }, 400);
  }

  const message = String(body["message"] ?? "").trim();
  if (!message) {
    return json({ error: "empty_message" }, 400);
  }

  const ticketIdRaw = body["ticket_id"] as string | undefined ??
    body["ticketId"] as string | undefined;

  const admin = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const user = await getUserFromJwt(admin, jwt);
  if (!user) {
    return json({ error: "invalid_jwt" }, 401);
  }

  const resolved = await resolveTicketId(
    admin,
    user.id,
    userType,
    ticketIdRaw?.trim() || undefined,
  );
  if ("error" in resolved) {
    return json({ error: resolved.error }, resolved.status);
  }
  const ticketId = resolved.ticketId;

  const { data: ticket, error: loadErr } = await admin
    .from("tickets")
    .select("id, messages, status")
    .eq("id", ticketId)
    .single();

  if (loadErr || !ticket) {
    console.error("load ticket:", loadErr);
    return json({ error: "ticket_load_failed" }, 500);
  }

  const status = (ticket.status as string) ?? "open";
  const lowerStatus = status.toLowerCase();
  const shouldReopen = lowerStatus === "closed" || lowerStatus === "resolved" ||
    lowerStatus === "auto_resolved";

  const existing = Array.isArray(ticket.messages)
    ? [...ticket.messages as unknown[]]
    : [];

  const now = new Date().toISOString();
  const userRow = { role: "user", content: message, ts: now };
  const withUser = [...existing, userRow];

  // Persist the user's message before calling the AI provider. Provider outages
  // must never erase a support request or leave an empty ticket behind.
  const { error: userPersistError } = await admin
    .from("tickets")
    .update({
      messages: withUser,
      status: shouldReopen ? "open" : status,
      updated_at: now,
    })
    .eq("id", ticketId);

  if (userPersistError) {
    console.error("ticket user message update:", userPersistError);
    return json({ error: "persist_failed" }, 500);
  }

  const turns = buildChatTurnsFromMessages(withUser);
  const sys = systemPrompt(userType);
  const apiMessages: ChatTurn[] = [
    { role: "system", content: sys },
    ...turns,
  ];

  let reply: string;
  let responseModel: string | null = null;
  let usedFallbackModel = false;
  let degraded = false;
  try {
    if (!apiKey) throw new Error("OPENROUTER_API_KEY missing");
    const completion = await callOpenRouterWithFallback(
      apiMessages,
      model,
      apiKey,
    );
    reply = completion.text;
    responseModel = completion.model;
    usedFallbackModel = completion.usedFallbackModel;
  } catch (e) {
    console.error("OpenRouter exhausted all models:", e);
    reply = providerUnavailableReply(userType, message);
    degraded = true;
  }

  const assistantRow = {
    role: "assistant",
    content: reply,
    ts: new Date().toISOString(),
  };
  const finalMessages = [...withUser, assistantRow];

  const { error: upErr } = await admin
    .from("tickets")
    .update({
      messages: finalMessages,
      status: shouldReopen ? "open" : status,
      updated_at: new Date().toISOString(),
    })
    .eq("id", ticketId);

  if (upErr) {
    console.error("ticket update:", upErr);
    return json({ error: "persist_failed" }, 500);
  }

  return json({
    reply,
    ticket_id: ticketId,
    degraded,
    model: responseModel,
    used_fallback_model: usedFallbackModel,
  });
}
