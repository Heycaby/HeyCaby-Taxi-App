# Driver support chat (Lee) — Flutter ↔ `driver-support-chat`

## Edge Function

- **Name:** `driver-support-chat` — **no LLM API key in the app.**
- **Provider:** **OpenRouter** chat completions (see **`AI_CHAT_AGENT_BACKEND_SPEC.md`**).
- **Secrets:** `OPENROUTER_API_KEY`, optional `SUPPORT_AI_MODEL` (default `openrouter/free`).

## Flutter

- **Service:** `DriverDataService.sendDriverSupportChatMessage(message:, ticketId:)` — JWT in `Authorization` header on invoke.
- **UI:** `SupportChatScreen` loads by **`ticketId`**, sends through the function, reloads `tickets` for **legacy** + **Lee** message shapes.
- **Threads:** preview uses `content` or `body`.

## Privacy

- `tickets.user_id` tied to `auth.uid()`; Edge Function verifies ownership before updates (service role + explicit checks).
