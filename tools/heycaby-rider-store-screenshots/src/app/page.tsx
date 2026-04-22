"use client";

import { toPng } from "html-to-image";
import {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
  type CSSProperties,
} from "react";

const DESIGN_W = 1320;
const DESIGN_H = 2868;

/** Set to `"png"` after adding 6.1″ simulator captures (`slide-01.png` … `slide-06.png`) per locale. */
const SCREEN_EXT = "svg" as const;

const IPHONE_SIZES = [
  { label: '6.9"', w: 1320, h: 2868 },
  { label: '6.5"', w: 1284, h: 2778 },
  { label: '6.3"', w: 1206, h: 2622 },
  { label: '6.1"', w: 1125, h: 2436 },
] as const;

const LOCALES = ["en", "nl", "ar"] as const;
type Locale = (typeof LOCALES)[number];

const RTL_LOCALES = new Set<Locale>(["ar"]);

const THEMES = {
  "taxi-light": {
    bg: "#fafaf9",
    fg: "#111111",
    accent: "#E6A800",
    muted: "#525252",
    surface: "#ffffff",
  },
  "taxi-dark": {
    bg: "#0a0a0a",
    fg: "#fafafa",
    accent: "#E6A800",
    muted: "#a3a3a3",
    surface: "#171717",
  },
} as const;
type ThemeId = keyof typeof THEMES;

type SlideCopy = {
  slug: string;
  label: string;
  line1: string;
  line2: string;
};

const COPY_BY_LOCALE: Record<Locale, SlideCopy[]> = {
  en: [
    { slug: "hero", label: "RIDER", line1: "Licensed taxis", line2: "No middleman fee" },
    { slug: "booking", label: "PICKUP", line1: "Your ride starts", line2: "In two taps" },
    { slug: "live", label: "LIVE", line1: "See your driver", line2: "Before they arrive" },
    { slug: "favourites", label: "TRUST", line1: "Ride with drivers", line2: "You already know" },
    { slug: "pay", label: "PAY", line1: "Cash, card, Tikkie", line2: "You choose how" },
    { slug: "more", label: "NL", line1: "Built for riders", line2: "In the Netherlands" },
  ],
  nl: [
    { slug: "hero", label: "RIDER", line1: "Erkende taxi’s", line2: "Zonder tussenfee" },
    { slug: "booking", label: "OPHALEN", line1: "Je rit begint", line2: "In twee tikken" },
    { slug: "live", label: "LIVE", line1: "Zie je chauffeur", line2: "Voordat hij er is" },
    { slug: "favourites", label: "VERTROUWEN", line1: "Rij met chauffeurs", line2: "Die jij kent" },
    { slug: "pay", label: "BETAAL", line1: "Contant, pin, Tikkie", line2: "Jij kiest" },
    { slug: "more", label: "NL", line1: "Gemaakt voor NL", line2: "Rijden zonder gedoe" },
  ],
  ar: [
    { slug: "hero", label: "راكب", line1: "سيارات أجرة مرخّصة", line2: "بدون وسيط" },
    { slug: "booking", label: "الاستلام", line1: "رحلتك تبدأ", line2: "بلمسنتين" },
    { slug: "live", label: "مباشر", line1: "شاهد السائق", line2: "قبل الوصول" },
    { slug: "favourites", label: "ثقة", line1: "اركب مع سائقين", line2: "تعرفهم" },
    { slug: "pay", label: "الدفع", line1: "نقدًا أو بطاقة", line2: "أنت تقرر" },
    { slug: "more", label: "هولندا", line1: "مصمّم للركاب", line2: "في هولندا" },
  ],
};

function slideSrc(base: string, index: number) {
  return `${base}/slide-${String(index + 1).padStart(2, "0")}.${SCREEN_EXT}`;
}

function PhoneFrame({
  src,
  alt,
  widthPx,
}: {
  src: string;
  alt: string;
  widthPx: number;
}) {
  const pad = Math.round(widthPx * 0.028);
  const innerR = Math.round(widthPx * 0.065);
  return (
    <div
      style={{
        width: widthPx,
        aspectRatio: "1125 / 2436",
        position: "relative",
        borderRadius: innerR + pad,
        padding: pad,
        background: "linear-gradient(160deg, #3f3f42 0%, #1a1a1c 100%)",
        boxShadow:
          "0 24px 64px rgba(0,0,0,0.35), inset 0 1px 0 rgba(255,255,255,0.08)",
      }}
    >
      <div
        style={{
          width: "100%",
          height: "100%",
          borderRadius: innerR,
          overflow: "hidden",
          background: "#000",
        }}
      >
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img
          src={src}
          alt={alt}
          style={{
            display: "block",
            width: "100%",
            height: "100%",
            objectFit: "cover",
            objectPosition: "top",
          }}
          draggable={false}
        />
      </div>
    </div>
  );
}

function Caption({
  label,
  line1,
  line2,
  canvasW,
  fg,
  accent,
}: {
  label: string;
  line1: string;
  line2: string;
  canvasW: number;
  fg: string;
  accent: string;
}) {
  return (
    <div>
      <div
        style={{
          fontSize: canvasW * 0.028,
          fontWeight: 700,
          letterSpacing: "0.12em",
          color: accent,
          marginBottom: canvasW * 0.022,
          textTransform: "uppercase",
        }}
      >
        {label}
      </div>
      <div
        style={{
          fontSize: canvasW * 0.092,
          fontWeight: 800,
          lineHeight: 1.02,
          color: fg,
        }}
      >
        {line1}
        <br />
        {line2}
      </div>
    </div>
  );
}

type SlideCanvasProps = {
  index: number;
  locale: Locale;
  themeId: ThemeId;
  base: string;
};

function SlideCanvas({ index, locale, themeId, base }: SlideCanvasProps) {
  const theme = THEMES[themeId];
  const isDark = themeId === "taxi-dark";
  const isRtl = RTL_LOCALES.has(locale);
  const copy = COPY_BY_LOCALE[locale][index];
  const src = slideSrc(base, index);
  const W = DESIGN_W;
  const H = DESIGN_H;
  const dir = isRtl ? "rtl" : "ltr";

  const commonFont: CSSProperties = {
    fontFamily: "var(--font-pj), ui-sans-serif, system-ui, sans-serif",
  };

  if (index === 0) {
    return (
      <div
        dir={dir}
        style={{
          width: W,
          height: H,
          position: "relative",
          overflow: "hidden",
          ...commonFont,
          background: isDark
            ? `linear-gradient(165deg, #171717 0%, #0f0f0f 45%, #0a0a0a 100%)`
            : `linear-gradient(165deg, ${theme.surface} 0%, #f0efe9 45%, #ebe8e0 100%)`,
        }}
      >
        <div
          style={{
            position: "absolute",
            width: W * 0.55,
            height: W * 0.55,
            borderRadius: "50%",
            background: theme.accent,
            opacity: 0.12,
            top: -W * 0.08,
            [isRtl ? "left" : "right"]: -W * 0.05,
            filter: "blur(40px)",
          }}
        />
        <div
          style={{
            position: "absolute",
            top: W * 0.12,
            [isRtl ? "right" : "left"]: W * 0.065,
            width: W * 0.42,
          }}
        >
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src="/app-icon.svg"
            alt=""
            width={Math.round(W * 0.11)}
            height={Math.round(W * 0.11)}
            style={{ marginBottom: W * 0.035, borderRadius: W * 0.024 }}
            draggable={false}
          />
          <Caption
            label={copy.label}
            line1={copy.line1}
            line2={copy.line2}
            canvasW={W}
            fg={theme.fg}
            accent={theme.accent}
          />
        </div>
        <div
          style={{
            position: "absolute",
            left: "50%",
            bottom: 0,
            transform: "translateX(-50%) translateY(11%)",
            width: W * 0.58,
          }}
        >
          <PhoneFrame src={src} alt="" widthPx={W * 0.58} />
        </div>
      </div>
    );
  }

  if (index === 1) {
    return (
      <div
        dir={dir}
        style={{
          width: W,
          height: H,
          position: "relative",
          overflow: "hidden",
          ...commonFont,
          background: isDark
            ? `linear-gradient(135deg, #1a1a1a 0%, ${theme.surface} 50%, #0f0f0f 100%)`
            : `linear-gradient(135deg, #f7f3eb 0%, ${theme.surface} 50%, #efe9dc 100%)`,
        }}
      >
        <div
          style={{
            position: "absolute",
            top: W * 0.14,
            [isRtl ? "right" : "left"]: W * 0.065,
            width: W * 0.44,
          }}
        >
          <Caption
            label={copy.label}
            line1={copy.line1}
            line2={copy.line2}
            canvasW={W}
            fg={theme.fg}
            accent={theme.accent}
          />
        </div>
        <div
          style={{
            position: "absolute",
            [isRtl ? "left" : "right"]: -W * 0.02,
            bottom: 0,
            transform: `translateY(10%) rotate(${isRtl ? 3 : -3}deg)`,
            width: W * 0.52,
          }}
        >
          <PhoneFrame src={src} alt="" widthPx={W * 0.52} />
        </div>
      </div>
    );
  }

  if (index === 2) {
    return (
      <div
        dir={dir}
        style={{
          width: W,
          height: H,
          position: "relative",
          overflow: "hidden",
          ...commonFont,
          background: isDark
            ? "linear-gradient(180deg, #2a2824 0%, #1c1b18 55%, #121110 100%)"
            : "linear-gradient(180deg, #ddd8cf 0%, #c9c3b8 55%, #b8b2a8 100%)",
        }}
      >
        <div
          style={{
            position: "absolute",
            top: W * 0.1,
            left: "50%",
            transform: "translateX(-50%)",
            width: W * 0.78,
            textAlign: "center",
          }}
        >
          <Caption
            label={copy.label}
            line1={copy.line1}
            line2={copy.line2}
            canvasW={W}
            fg={isDark ? theme.fg : "#1a1a1a"}
            accent={isDark ? theme.accent : "#b45309"}
          />
        </div>
        <div
          style={{
            position: "absolute",
            left: "50%",
            bottom: 0,
            transform: "translateX(-50%) translateY(12%)",
            width: W * 0.62,
          }}
        >
          <PhoneFrame src={src} alt="" widthPx={W * 0.62} />
        </div>
      </div>
    );
  }

  if (index === 3) {
    return (
      <div
        dir={dir}
        style={{
          width: W,
          height: H,
          position: "relative",
          overflow: "hidden",
          ...commonFont,
          background: isDark
            ? `linear-gradient(160deg, #141414 0%, #0a0a0a 100%)`
            : `linear-gradient(160deg, ${theme.surface} 0%, #f5f2ea 100%)`,
        }}
      >
        <div
          style={{
            position: "absolute",
            width: W * 0.7,
            height: W * 0.7,
            borderRadius: "50%",
            background: theme.accent,
            opacity: 0.15,
            bottom: H * 0.15,
            [isRtl ? "right" : "left"]: -W * 0.15,
            filter: "blur(48px)",
          }}
        />
        <div
          style={{
            position: "absolute",
            top: W * 0.16,
            [isRtl ? "left" : "right"]: W * 0.065,
            width: W * 0.4,
            textAlign: isRtl ? "right" : "left",
          }}
        >
          <Caption
            label={copy.label}
            line1={copy.line1}
            line2={copy.line2}
            canvasW={W}
            fg={theme.fg}
            accent={theme.accent}
          />
        </div>
        <div
          style={{
            position: "absolute",
            [isRtl ? "right" : "left"]: -W * 0.06,
            bottom: 0,
            transform: "translateY(9%)",
            width: W * 0.56,
          }}
        >
          <PhoneFrame src={src} alt="" widthPx={W * 0.56} />
        </div>
      </div>
    );
  }

  if (index === 4) {
    return (
      <div
        dir={dir}
        style={{
          width: W,
          height: H,
          position: "relative",
          overflow: "hidden",
          ...commonFont,
          background: isDark
            ? "linear-gradient(180deg, #181818 0%, #0c0c0c 100%)"
            : "linear-gradient(180deg, #fbf9f4 0%, #f3efe6 100%)",
        }}
      >
        <div
          style={{
            position: "absolute",
            top: W * 0.11,
            [isRtl ? "right" : "left"]: W * 0.065,
            width: W * 0.5,
          }}
        >
          <Caption
            label={copy.label}
            line1={copy.line1}
            line2={copy.line2}
            canvasW={W}
            fg={isDark ? theme.fg : "#1c1917"}
            accent={theme.accent}
          />
        </div>
        <div
          style={{
            position: "absolute",
            left: "50%",
            bottom: 0,
            transform: "translateX(-50%) translateY(10%)",
            width: W * 0.54,
          }}
        >
          <PhoneFrame src={src} alt="" widthPx={W * 0.54} />
        </div>
      </div>
    );
  }

  return (
    <div
      dir={dir}
      style={{
        width: W,
        height: H,
        position: "relative",
        overflow: "hidden",
        ...commonFont,
        background: `radial-gradient(ellipse 120% 80% at 50% 0%, #262626 0%, #0a0a0a 55%, #000 100%)`,
      }}
    >
      <div
        style={{
          position: "absolute",
          top: W * 0.12,
          left: W * 0.065,
          right: W * 0.065,
          width: W * 0.87,
        }}
      >
        <Caption
          label={copy.label}
          line1={copy.line1}
          line2={copy.line2}
          canvasW={W}
          fg="#fafafa"
          accent={theme.accent}
        />
        <div
          style={{
            marginTop: W * 0.04,
            height: Math.max(6, W * 0.008),
            width: W * 0.22,
            borderRadius: 4,
            background: theme.accent,
            marginLeft: isRtl ? "auto" : 0,
            marginRight: isRtl ? 0 : "auto",
          }}
        />
      </div>
      <div
        style={{
          position: "absolute",
          left: "50%",
          bottom: 0,
          transform: "translateX(-50%) translateY(14%)",
          width: W * 0.48,
          opacity: 0.95,
        }}
      >
        <PhoneFrame src={src} alt="" widthPx={W * 0.48} />
      </div>
    </div>
  );
}

function sleep(ms: number) {
  return new Promise((r) => setTimeout(r, ms));
}

async function exportNode(
  el: HTMLElement,
  outW: number,
  outH: number,
  filename: string,
) {
  const prev = {
    position: el.style.position,
    left: el.style.left,
    top: el.style.top,
    opacity: el.style.opacity,
    zIndex: el.style.zIndex,
    pointerEvents: el.style.pointerEvents,
  };
  el.style.position = "fixed";
  el.style.left = "0px";
  el.style.top = "0px";
  el.style.opacity = "1";
  el.style.zIndex = "2147483646";
  el.style.pointerEvents = "none";

  const opts = {
    width: outW,
    height: outH,
    pixelRatio: 1,
    cacheBust: true,
    style: { transform: "none" },
  } as const;

  try {
    await toPng(el, opts);
    const dataUrl = await toPng(el, opts);
    const a = document.createElement("a");
    a.href = dataUrl;
    a.download = filename;
    a.click();
  } finally {
    el.style.position = prev.position;
    el.style.left = prev.left;
    el.style.top = prev.top;
    el.style.opacity = prev.opacity;
    el.style.zIndex = prev.zIndex;
    el.style.pointerEvents = prev.pointerEvents;
  }
}

const PREVIEW_SCALE = 0.2;

export default function ScreenshotsPage() {
  const [locale, setLocale] = useState<Locale>("en");
  const [themeId, setThemeId] = useState<ThemeId>("taxi-light");
  const [sizeIdx, setSizeIdx] = useState(0);
  const [busy, setBusy] = useState(false);
  const offscreenRefs = useRef<(HTMLDivElement | null)[]>([]);

  useEffect(() => {
    const q = new URLSearchParams(window.location.search);
    const l = q.get("locale") as Locale | null;
    if (l && LOCALES.includes(l)) setLocale(l);
    const t = q.get("theme") as ThemeId | null;
    if (t && t in THEMES) setThemeId(t);
  }, []);

  const base = `/screenshots/${locale}`;
  const size = IPHONE_SIZES[sizeIdx];
  const slideCount = COPY_BY_LOCALE.en.length;

  const setRef = useCallback((i: number) => {
    return (el: HTMLDivElement | null) => {
      offscreenRefs.current[i] = el;
    };
  }, []);

  const runExportOne = useCallback(
    async (index: number) => {
      const el = offscreenRefs.current[index];
      if (!el) return;
      const copy = COPY_BY_LOCALE[locale][index];
      const name = `${String(index + 1).padStart(2, "0")}-${copy.slug}-${locale}-${themeId}-iphone-${size.w}x${size.h}.png`;
      await exportNode(el, size.w, size.h, name);
    },
    [locale, themeId, size.w, size.h],
  );

  const runExportAll = useCallback(async () => {
    setBusy(true);
    try {
      for (let i = 0; i < slideCount; i++) {
        await runExportOne(i);
        await sleep(320);
      }
    } finally {
      setBusy(false);
    }
  }, [runExportOne, slideCount]);

  const toolbar = useMemo(
    () => (
      <div className="flex flex-wrap items-center gap-3 border-b border-neutral-200 bg-white/90 px-4 py-3 backdrop-blur-sm dark:border-neutral-800 dark:bg-neutral-950/90">
        <span className="text-sm font-semibold text-neutral-800 dark:text-neutral-100">
          HeyCaby Rider
        </span>
        <div className="flex flex-wrap gap-1">
          {LOCALES.map((l) => (
            <button
              key={l}
              type="button"
              onClick={() => setLocale(l)}
              className={`rounded-md px-2.5 py-1 text-xs font-semibold uppercase ${
                locale === l
                  ? "bg-amber-500 text-black"
                  : "bg-neutral-200 text-neutral-700 dark:bg-neutral-800 dark:text-neutral-300"
              }`}
            >
              {l}
            </button>
          ))}
        </div>
        <div className="flex flex-wrap gap-1">
          {(Object.keys(THEMES) as ThemeId[]).map((t) => (
            <button
              key={t}
              type="button"
              onClick={() => setThemeId(t)}
              className={`rounded-md px-2.5 py-1 text-xs font-medium ${
                themeId === t
                  ? "bg-neutral-900 text-white dark:bg-white dark:text-black"
                  : "bg-neutral-100 text-neutral-600 dark:bg-neutral-900 dark:text-neutral-400"
              }`}
            >
              {t}
            </button>
          ))}
        </div>
        <select
          className="rounded-md border border-neutral-300 bg-white px-2 py-1 text-sm dark:border-neutral-700 dark:bg-neutral-900"
          value={sizeIdx}
          onChange={(e) => setSizeIdx(Number(e.target.value))}
        >
          {IPHONE_SIZES.map((s, i) => (
            <option key={s.label} value={i}>
              {s.label} ({s.w}×{s.h})
            </option>
          ))}
        </select>
        <button
          type="button"
          disabled={busy}
          onClick={runExportAll}
          className="ml-auto rounded-lg bg-amber-500 px-4 py-2 text-sm font-bold text-black disabled:opacity-50"
        >
          {busy ? "Exporting…" : "Export all PNGs"}
        </button>
      </div>
    ),
    [locale, themeId, sizeIdx, busy, runExportAll],
  );

  return (
    <div className="min-h-full flex flex-col bg-neutral-100 dark:bg-neutral-950">
      {toolbar}
      <div className="mx-auto max-w-7xl px-4 py-6">
        <p className="mb-4 text-sm text-neutral-600 dark:text-neutral-400">
          Replace SVGs in{" "}
          <code className="rounded bg-neutral-200 px-1 dark:bg-neutral-800">
            public/screenshots/&lt;locale&gt;/slide-*.svg
          </code>{" "}
          with real 6.1″ simulator PNGs (same filenames). See{" "}
          <code className="rounded bg-neutral-200 px-1 dark:bg-neutral-800">
            docs/APP_STORE_SCREENSHOTS.md
          </code>
          .
        </p>
        <div className="grid gap-8 sm:grid-cols-2 xl:grid-cols-3">
          {Array.from({ length: slideCount }, (_, i) => (
            <div key={i} className="flex flex-col gap-2">
              <div
                className="overflow-hidden rounded-xl border border-neutral-200 bg-neutral-50 shadow-sm dark:border-neutral-800 dark:bg-neutral-900"
                style={{
                  width: DESIGN_W * PREVIEW_SCALE,
                  height: DESIGN_H * PREVIEW_SCALE,
                }}
              >
                <div
                  style={{
                    width: DESIGN_W,
                    height: DESIGN_H,
                    transform: `scale(${PREVIEW_SCALE})`,
                    transformOrigin: "top left",
                  }}
                >
                  <SlideCanvas
                    index={i}
                    locale={locale}
                    themeId={themeId}
                    base={base}
                  />
                </div>
              </div>
              <button
                type="button"
                disabled={busy}
                onClick={() => runExportOne(i)}
                className="rounded-lg border border-neutral-300 bg-white px-3 py-1.5 text-sm font-medium text-neutral-800 hover:bg-neutral-50 disabled:opacity-50 dark:border-neutral-700 dark:bg-neutral-900 dark:text-neutral-200 dark:hover:bg-neutral-800"
              >
                Export {String(i + 1).padStart(2, "0")} —{" "}
                {COPY_BY_LOCALE[locale][i].slug}
              </button>
            </div>
          ))}
        </div>
      </div>

      {Array.from({ length: slideCount }, (_, i) => (
        <div
          key={`off-${i}`}
          ref={setRef(i)}
          aria-hidden
          style={{
            position: "fixed",
            left: -9999,
            top: 0,
            width: DESIGN_W,
            height: DESIGN_H,
            overflow: "hidden",
            pointerEvents: "none",
          }}
        >
          <SlideCanvas
            index={i}
            locale={locale}
            themeId={themeId}
            base={base}
          />
        </div>
      ))}
    </div>
  );
}
