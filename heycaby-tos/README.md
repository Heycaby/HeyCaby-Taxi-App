# HeyCaby — driver legal pages (static HTML)

These files are the **canonical web copies** of the chauffeur **Terms** and **Support** pages. Style tokens align with the Flutter driver app (`kTaxiShade6` / `kTaxiShade2`: cream background, gold accent `#E6A800`, near-black text).

## Published URLs (production)

| Page | Clean URL | File (in repo) |
|------|-------------|----------------|
| Algemene Voorwaarden Chauffeurs | `https://www.heycaby.nl/chauffeur/voorwaarden` | `chauffeur/voorwaarden/index.html` |
| Vrijwaring & aansprakelijkheid (EN/NL) | `https://www.heycaby.nl/chauffeur/vrijwaring` | `chauffeur/vrijwaring/index.html` |
| Veriff section (anchor) | `…/chauffeur/voorwaarden#a3` | §3 in that file |
| Support / FAQ | `https://www.heycaby.nl/support` | `support/index.html` |

**Important:** The app already uses `www.heycaby.nl` in `driver_legal_urls.dart`. You must **attach the domain `www.heycaby.nl`** to the Vercel project that serves these files, or copy the folders into your main Next.js `public/` — see **`WWW_HEYCABY_NL.md`**.

## Deploy on Vercel (this folder)

This directory is a **static site**. Files live at the **same paths as the public URL**:

- `chauffeur/voorwaarden/index.html` → `/chauffeur/voorwaarden`
- `chauffeur/vrijwaring/index.html` → `/chauffeur/vrijwaring`
- `support/index.html` → `/support`

### Steps

1. In [Vercel](https://vercel.com) → **Add New** → **Project** → import this Git repo.
2. Set **Root Directory** to `heycaby-tos` (important in a monorepo).
3. Framework: **Other** (static). No build command needed.
4. **Deploy**. You should get a URL like `heycaby-tos-….vercel.app` where `/chauffeur/voorwaarden`, `/chauffeur/vrijwaring`, and `/support` work.
5. **Domains** → add `www.heycaby.nl` (and optionally `heycaby.nl` redirecting to `www`).

**Production deploy** (after `vercel login`; team scope required for CI/non-interactive):

```bash
cd heycaby-tos && npm run deploy
```

**Live Vercel URLs** (add `www.heycaby.nl` in Vercel → Domains when DNS is ready):

| | URL |
|---|-----|
| Production alias | https://heycaby-tos.vercel.app |
| Chauffeur terms | https://heycaby-tos.vercel.app/chauffeur/voorwaarden |
| Chauffeur vrijwaring | https://heycaby-tos.vercel.app/chauffeur/vrijwaring |
| Support | https://heycaby-tos.vercel.app/support |

Test these before pointing `www.heycaby.nl` at this project.

## Flutter app integration

Defaults in `apps/driver/lib/config/driver_legal_urls.dart`:

- `https://www.heycaby.nl/chauffeur/voorwaarden`
- Override with `--dart-define=DRIVER_TERMS_URL=…` for previews (e.g. your `*.vercel.app` URL during QA).

The **Veriff** flow uses a terms gate before opening Veriff; see `apps/driver/docs/VERIFF_FLUTTER.md`.

## Deploy checklist (content)

1. Update **KvK** and placeholders in `chauffeur/voorwaarden/index.html` §13 before marketing use.
2. In **Veriff Station**, point **Terms** / callback docs to the same public URLs if required.
3. Have a **Dutch lawyer** review before calling the text final.

## Local preview

```bash
cd heycaby-tos && python3 -m http.server 8765
# http://localhost:8765/chauffeur/voorwaarden/
# http://localhost:8765/chauffeur/vrijwaring/
# http://localhost:8765/support/
```
