# HeyCaby AI support chat — Supabase Edge + OpenRouter

**Edge Functions (in repo):** `driver-support-chat`, `rider-support-chat`.  
**Flutter:** never holds LLM API keys; only invokes the function with the user JWT (`Authorization: Bearer <access_token>`).

## Secrets (Dashboard → Edge Functions → Secrets)

| Secret | Purpose |
|--------|---------|
| `OPENROUTER_API_KEY` | [OpenRouter](https://openrouter.ai/) API key — required for AI replies. |
| `SUPPORT_AI_MODEL` | Optional. Default **`openrouter/free`** (zero-cost router; OpenRouter picks a free model). Override with any OpenRouter model id (e.g. a specific free-tier slug from their model list). |
| `OPENROUTER_SITE_URL` | Optional `HTTP-Referer` for OpenRouter (defaults to `SUPABASE_URL` or `https://heycaby.nl`). |
| `OPENROUTER_APP_TITLE` | Optional `X-Title` header (default `HeyCaby Support`). |

## API

Both functions use **OpenRouter Chat Completions**: `POST https://openrouter.ai/api/v1/chat/completions` with `{ "model", "messages" }`. Replies are read from `choices[0].message.content` (including simple multimodal text-array shapes).

## Behaviour

1. Validates JWT → Supabase Auth user id.
2. Resolves **`tickets`** row: `ticket_id` in body if provided (must match `user_id` + `user_type`); else latest **`status = open`** ticket; else inserts a new row (`category: ai_support`).
3. Rejects if ticket is **`closed`** or **`resolved`** (`409 ticket_closed`).
4. Persists the **`{ role, content, ts }`** user row before calling OpenRouter, so an upstream outage cannot erase the support request.
5. Calls the configured OpenRouter model and falls back to **`openrouter/free`** when that model is unavailable.
6. Appends the assistant row. If every provider attempt fails or the provider secret is unavailable, the ticket remains usable and receives a clearly labelled support fallback response.
7. Returns **`{ reply, ticket_id, degraded, model, used_fallback_model }`**.

## Flutter (this monorepo)

- **Driver:** `DriverDataService.sendDriverSupportChatMessage` → `driver-support-chat`.
- **Rider:** `RiderSupportChatService.sendMessage` → `rider-support-chat`.
- UIs render Lee-style **`role` / `content` / `ts`** and legacy ticket shapes.

## Historical note

Earlier docs described **OpenAI Responses API** + `OPENAI_API_KEY`. The **checked-in** Edge implementation uses **OpenRouter** only; migrate by setting `OPENROUTER_API_KEY` and deploying the functions from `supabase/functions/`.

## References

- [OpenRouter API](https://openrouter.ai/docs/quickstart)
- [Free models router](https://openrouter.ai/docs/guides/routing/routers/free-models-router)
