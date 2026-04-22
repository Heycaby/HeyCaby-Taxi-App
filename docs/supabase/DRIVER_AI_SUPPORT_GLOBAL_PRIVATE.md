# Driver AI customer service (Supabase) — global rollout + per-driver privacy

Use this when wiring **OpenAI** for **all drivers** while ensuring **Driver A never sees Driver B’s tickets or chat**. Set the exact model id in secrets (e.g. **`gpt-5.4-mini`** for Lee / `driver-support-chat` v2 — see **`DRIVER_SUPPORT_CHAT_LEE.md`**).

## What “global” means here

- **One Supabase project**, **one set of tables**, **one Edge Function** (e.g. **`driver-support-chat`** for Lee), **one** `OPENAI_API_KEY` stored as a **Supabase secret** (Dashboard → Edge Functions → Secrets).
- Every driver uses the **same** function and schema; behaviour is “global” in ops, not “one shared conversation”.

## What “private” means (non‑negotiable)

Isolation is enforced in **PostgreSQL with Row Level Security (RLS)**, not only in the app:

| Layer | Responsibility |
|--------|----------------|
| **RLS** | Each row is visible only if `user_id` matches `auth.uid()` (for drivers: `user_type = 'driver'`). |
| **Edge Function** | Verifies JWT, uses `auth.uid()` from the verified token, loads/updates **only** that user’s ticket(s). Never trust `user_id` from the request body without matching the JWT. |
| **Client** | Only calls the function with `Authorization: Bearer <session_jwt>`; does **not** hold the OpenAI key. |

Driver A cannot `SELECT` Driver B’s rows even with a modified client if RLS is correct.

## Recommended data model (align with your existing `tickets` table)

Your docs already describe **`tickets`** with:

- `user_type` (e.g. `'driver'`)
- `user_id` — **text**, equals **`auth.uid()` as string** for that driver
- `messages` — JSONB array of message objects
- `status`, `category`, etc.

**Privacy rule:** one ticket row = one support thread. Each row’s `user_id` must be the owning driver’s auth id. **RLS:** allow `SELECT/INSERT/UPDATE` only when:

```sql
user_type = 'driver'
AND user_id = auth.uid()::text
```

(Optional) Add `source = 'ai_agent'` or `category = 'driver_ai_support'` to distinguish AI threads from human support.

### Message JSON (extend your existing array)

Add AI turns with a clear `sender_type` so the UI can render them:

```json
{
  "id": "uuid",
  "sender_type": "driver",
  "body": "How do I change my rates?",
  "created_at": "2026-03-18T10:00:00Z"
}
```

```json
{
  "id": "uuid",
  "sender_type": "assistant",
  "body": "You can…",
  "created_at": "2026-03-18T10:00:01Z",
  "model": "gpt-5.4-mini"
}
```

Store **only** what you’re allowed to retain (privacy policy / retention). Avoid putting secrets or full PII of other users in messages.

## Edge Function `driver-support-chat` (Lee / v2) — high level

1. **Auth:** Read JWT from `Authorization`, verify with Supabase (or use `createClient` with the anon key + user JWT so RLS applies).
2. **Resolve user:** `sub` / `auth.uid()` = the only driver identity you trust.
3. **Load context:** `SELECT` from `tickets` where `user_id = auth.uid()::text` OR create a new ticket row for this conversation.
4. **Call OpenAI:** Server-side `OPENAI_API_KEY` + `OPENAI_MODEL` (e.g. **`gpt-5.4-mini`**); **v2** uses the **Responses API** — see **`AI_CHAT_AGENT_BACKEND_SPEC.md`**.
5. **Persist:** Append user message + assistant reply to `tickets.messages` JSONB (or `UPDATE` via a small RPC that validates ownership).
6. **Return:** Assistant text + ticket id to the app.

**Never** pass `user_id` from the client as the authority for whose row to write; **always** derive from JWT.

## RLS checklist (Supabase SQL)

- `ENABLE ROW LEVEL SECURITY` on `tickets`.
- Policies for **`authenticated`** role:
  - **SELECT:** `user_type = 'driver' AND user_id = auth.uid()::text`
  - **INSERT:** same (and optionally restrict insertable columns).
  - **UPDATE:** same row predicate.
- **Service role** (Edge Function with service key if you bypass JWT for writes): use only in trusted server code, or prefer the user-scoped client so RLS keeps applying.

Re-test with two driver accounts: A can only see A’s `user_id`, B only B’s.

## “Global” vs shared knowledge

- **Shared:** system prompt, model, KB snippets (if you add RAG later), **Edge Function code**, **secrets**.
- **Not shared:** per-driver ticket rows, message history, and any embeddings stored per user (if you add RAG per user).

## Flutter app

- Call `supabase.functions.invoke('driver-support-chat', body: {'message': ..., 'ticket_id': ...})` with the **session** attached so the function receives the JWT.
- List tickets with `.from('tickets').select()` — RLS returns **only** the current driver’s rows.

## Model name

Set the **exact** OpenAI model id in secrets, e.g.:

`OPENAI_MODEL=gpt-5.4-mini`

Change the secret to switch models — no app store release required.

---

**Summary:** Global = one Supabase project + one Edge Function + secrets. Private = `tickets.user_id` tied to `auth.uid()` + strict RLS + JWT verified in the function. Driver A and B never share rows; they only share the same *infrastructure*.
