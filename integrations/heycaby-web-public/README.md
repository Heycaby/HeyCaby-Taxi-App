# Drop-in static pages for **heycaby-web** (www.heycaby.nl)

These files mirror `heycaby-tos/chauffeur/` and `heycaby-tos/support/` in this repo.  
**Production** is served by the HeyCaby Next.js app — copy into that repo’s `public/` folder so URLs work on the **same** deployment as **heycaby.nl**. (If the GitHub remote is still under another slug, use your actual clone path; the live site is **heycaby.nl**.)

| Public URL | Copy to in web `public/` |
|------------|--------------------------|
| `https://www.heycaby.nl/chauffeur/voorwaarden` | `public/chauffeur/voorwaarden/index.html` |
| `https://www.heycaby.nl/support` | `public/support/index.html` |

## One-time setup (from your machine)

```bash
# adjust path to your local web clone
export HEYCABY_WEB="$HOME/code/heycaby-web"   # example clone path

cp -R chauffeur "$HEYCABY_WEB/public/"
cp -R support "$HEYCABY_WEB/public/"

cd "$HEYCABY_WEB"
git add public/chauffeur public/support
git commit -m "feat(web): add chauffeur terms + support static pages for www.heycaby.nl"
git push
```

After deploy, open:

- https://www.heycaby.nl/chauffeur/voorwaarden  
- https://www.heycaby.nl/support  

## Keeping in sync

When legal HTML changes in **`heycaby-tos/`**, re-copy into the web `public/` folder (or run `scripts/sync-driver-legal-to-heycaby-web.sh` from the repo root with `HEYCABY_WEB_ROOT` set).

## Separate Vercel project `heycaby-tos`

Optional preview/staging only. **Do not** attach the production apex domain to that project if it already belongs to the main HeyCaby web deployment.
