# Why `https://www.heycaby.nl/chauffeur/voorwaarden` must be fixed in Vercel / DNS

The **path** `/chauffeur/voorwaarden` is correct. The Flutter app already uses:

`https://www.heycaby.nl/chauffeur/voorwaarden`

## Canonical production: **HeyCaby web** (Next.js PWA)

The domain **`heycaby.nl` / `www.heycaby.nl`** is registered on the **main HeyCaby web repository**, not this monorepo.

Put the static HTML under **`public/chauffeur/voorwaarden/index.html`** and **`public/support/index.html`** there, then deploy **HeyCaby web**. See **`integrations/heycaby-web-public/README.md`** and `scripts/sync-driver-legal-to-heycaby-web.sh`.

---

## Older options (only if you do **not** use HeyCaby web for these paths)

### Option A — Static-only Vercel project owns `www` (not recommended if HeyCaby web already uses www)

1. [Vercel Dashboard](https://vercel.com) → project **`heycaby-tos`** → **Settings** → **Domains**.
2. Add **`www.heycaby.nl`** (and optionally **`heycaby.nl`** with redirect to `www`).
3. Do what Vercel says for **DNS** at your registrar (usually a **CNAME** `www` → `cname.vercel-dns.com` or the target Vercel shows).
4. Wait for **SSL provisioned** (often a few minutes).

Then open: **https://www.heycaby.nl/chauffeur/voorwaarden**

### Option B — `www.heycaby.nl` already goes to your main app (e.g. Next.js **HeyCaby web**)

You **cannot** assign the same hostname to two Vercel projects. Do one of:

1. **Copy** these files into the **main** repo’s `public` folder so the paths exist on that deployment:
   - `public/chauffeur/voorwaarden/index.html` ← content from `heycaby-tos/chauffeur/voorwaarden/index.html`
   - `public/support/index.html` ← from `heycaby-tos/support/index.html`
2. Or add **rewrites** in `next.config.js` from `/chauffeur/voorwaarden` to a hosted asset.

After redeploying the **main** site, `https://www.heycaby.nl/chauffeur/voorwaarden` will work there.

## Verify

- On the deployment that has **`www.heycaby.nl`**:  
  `https://www.heycaby.nl/chauffeur/voorwaarden` → chauffeur terms  
  `https://www.heycaby.nl/support` → support  

## CLI: add domain (optional)

```bash
cd heycaby-tos
vercel domains add www.heycaby.nl --scope qbs-projects-2b124455
```

If Vercel says the domain is assigned to **another** project, remove it there first or use Option B.
