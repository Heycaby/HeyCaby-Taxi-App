# Lee (`driver-support-chat` v2) — checklist

## Ops (only required setup)

- [ ] Supabase **Dashboard → Edge Functions → Secrets**:
  - `OPENAI_API_KEY` = `sk-...` ([OpenAI API keys](https://platform.openai.com/api-keys))
  - `OPENAI_MODEL` = **`gpt-5.4-mini`** (v2 default; must match a model enabled for your API key)

Secrets are read at **runtime** — no redeploy needed when rotating keys or changing model string.

## Backend (deployed)

- **v2** uses **Responses API** (`/v1/responses`), not Chat Completions — see **`AI_CHAT_AGENT_BACKEND_SPEC.md`** for the OLD vs NEW summary.

## Dev (this repo)

- [x] `DriverDataService.sendDriverSupportChatMessage` → `driver-support-chat`
- [x] `SupportChatScreen` + ticket history + Lee/legacy bubbles

## Test

- [ ] Support → thread → send → Lee replies
- [ ] Second driver cannot read first driver’s tickets (RLS)

## Do not

- Put **`OPENAI_API_KEY`** in Flutter, `.env` committed to git, or client bundles.
- Rely on outdated docs that say **`gpt-5.4-mini` does not exist** — it is a valid GPT-5 family model id when your project has access.
