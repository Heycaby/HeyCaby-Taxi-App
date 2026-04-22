# App Store screenshot generation (HeyCaby)

This repo vendors the **[app-store-screenshots](https://github.com/ParthJadhav/app-store-screenshots)** project (MIT) under **`tools/app-store-screenshots/`**. It is a **Cursor / agent skill** plus workflow to build a small **Next.js** app that composes **marketing-style** App Store frames (not raw UI dumps), then exports PNGs at Apple’s required iPhone sizes via **`html-to-image`**.

## What was added

| Location | Purpose |
|----------|---------|
| `tools/app-store-screenshots/` | Upstream git clone (update with `git pull` inside that directory). |
| `.cursor/skills/app-store-screenshots/SKILL.md` | Cursor agent skill — read when you ask for App Store / marketing screenshots. |

Optional refresh from GitHub:

```bash
cd tools/app-store-screenshots && git pull origin main
cp skills/app-store-screenshots/SKILL.md ../../.cursor/skills/app-store-screenshots/SKILL.md
```

## How you (or Cursor) use it

### 1. Capture real UI (Flutter iOS)

Upstream recommends capturing **source** device shots on a **6.1″** simulator first so crops map cleanly to other sizes. See the upstream README: [ParthJadhav/app-store-screenshots](https://github.com/ParthJadhav/app-store-screenshots).

Suggested flow for **HeyCaby**:

1. Run **Rider** and **Driver** apps on an iPhone **6.1″** simulator (or the device size upstream documents).
2. Sign in with your **review** flows if needed (driver OTP / rider email + code for favourites).
3. Capture **PNG** screens for the stories you want on the store (home, booking, active ride, account, etc.).
4. Export **app icons** (1024×1024 and any marketing sizes you need).

### 2. Scaffold the generator (separate Next.js folder)

Do **not** put `node_modules` inside `apps/rider` or `apps/driver`. Create a **sibling** folder, e.g.:

```text
tools/heycaby-store-screenshots/   # new Next.js project (create-next-app + html-to-image)
```

The skill in **`.cursor/skills/app-store-screenshots/SKILL.md`** describes exact `create-next-app` flags, dependencies, and a single **`page.tsx`** pattern for slides + export.

### 3. Ask Cursor to run the skill

Example prompts:

```text
Using the app-store-screenshots skill, scaffold tools/heycaby-store-screenshots for HeyCaby Rider.
Brand: [colors, font]. Screenshots on disk: [path to PNGs]. Icon: [path].
6 slides: book a ride, live map, favourites, account, safety, marketplace.
Style: clean, premium, light background, accent from app.
```

```text
Same for HeyCaby Driver: onboarding, home/go online, documents, earnings, support.
```

The agent should follow **Step 1** in the skill (questions about assets, brand, slide count, locales, RTL) before coding.

### 4. Export PNGs

1. `cd tools/heycaby-store-screenshots && npm run dev` (or pnpm/bun/yarn).
2. Open the local URL, use the generator UI to export slides.
3. Upload to **App Store Connect** → your app → **App Preview and Screenshots**.

Resolutions the skill targets are documented upstream (e.g. 6.9″ / 6.5″ / 6.3″ / 6.1″ — see [README](https://github.com/ParthJadhav/app-store-screenshots/blob/main/README.md)).

## Alternative: `npx skills` (global install)

Upstream also documents:

```bash
npx skills add ParthJadhav/app-store-screenshots
```

That installs the skill for many agents; the vendored copy in this repo keeps the workflow **offline** and **version-pinned** to what you cloned.

## What the AI can deliver for you

Once you provide **screenshot PNGs**, **app icon**, **brand tokens**, and **priorities**, an agent with this skill can:

- Scaffold the Next.js + Tailwind + `html-to-image` project.
- Implement **ad-style** layouts (headline + device mockup + optional device screenshots inside the frame).
- Add **EN / NL / AR** copy variants or RTL where you ask.
- Output **exportable PNGs** at the sizes Apple expects.

The AI does **not** replace capturing **real** app UI: you still run the Flutter build on simulator/device; the generator **frames and sells** those captures.

## License

The upstream project is **MIT** — see `tools/app-store-screenshots/LICENSE`.
