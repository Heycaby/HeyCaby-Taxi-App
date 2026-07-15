# HeyCaby marketing website

Dutch-first public website for `heycaby.nl`. This is informational only: no browser booking, authentication, fare calculator, or fake live data.

## Local development

```bash
npm install
npm run dev
```

## Localization

The browser language is detected on first visit. Dutch is the fallback. Visitors can switch between NL, EN, and AR; Arabic activates RTL layout. Copy lives in `components/copy.ts`.

## Motion

The website uses CSS/IntersectionObserver motion with a complete `prefers-reduced-motion` fallback. Screenshot stories are data-driven and can later be imported into a Remotion composition without changing the narrative sequence.

## Required launch checks

- Confirm App Store and Play Store URLs in Vercel environment variables.
- Replace the supplied TestFlight captures with final clean production captures before public launch.
- Confirm launch-city coverage and verified testimonials before adding either to the page.
- Run Lighthouse against the Vercel preview.
