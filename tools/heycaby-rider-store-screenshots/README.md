# HeyCaby Rider — App Store screenshot generator

Next.js page that composes **marketing** frames (phone + headline) and exports PNGs at Apple iPhone sizes using `html-to-image`, following the repo skill `.cursor/skills/app-store-screenshots/SKILL.md`.

## Run

```bash
cd tools/heycaby-rider-store-screenshots
npm install
npm run dev
```

Open the printed URL, pick locale (en / nl / ar), optional theme, export size, then **Export all PNGs** or single-slide exports.

## Assets

- Placeholder screens live under `public/screenshots/<locale>/slide-01.svg` … `slide-06.svg`. Replace with **real 6.1″ simulator PNGs** named `slide-01.png` … `slide-06.png`, then in `src/app/page.tsx` set `SCREEN_EXT` to `"png"`.
- Marketing icon: `public/app-icon.svg` (swap for your real 1024×1024 asset if you prefer).

Workflow notes: `docs/APP_STORE_SCREENSHOTS.md`.
