import type { Metadata, Viewport } from "next";
import "./globals.css";

const SITE_URL = "https://www.heycaby.nl";
const OG_IMAGE = `${SITE_URL}/og-image.png`;

export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  title: {
    default: "HeyCaby — De taxi-app gebouwd door chauffeurs | 0% commissie",
    template: "%s | HeyCaby",
  },
  description:
    "HeyCaby is de Nederlandse taxi-app zonder commissie. Chauffeurs houden 100% van hun ritprijs. Rijders reizen met zichtbare veiligheid van boeking tot afzet. Boek veilig en eerlijk.",
  keywords: [
    "taxi app Nederland",
    "taxi app zonder commissie",
    "HeyCaby",
    "taxi Rotterdam",
    "taxi Nederland",
    "eerlijke taxi app",
    "taxi chauffeur app",
    "0% commissie taxi",
    "taxi boeken online",
    "veilige taxi app",
    "taxi Terug",
    "Nederlandse taxi community",
    "taxi app voor chauffeurs",
    "taxi app voor rijders",
    "fair taxi platform",
    "taxi service Netherlands",
    "taxi Amsterdam",
    "taxi Den Haag",
    "taxi Utrecht",
    "betaalbare taxi",
  ],
  authors: [{ name: "HeyCaby" }],
  creator: "HeyCaby",
  publisher: "HeyCaby",
  applicationName: "HeyCaby",
  category: "Transportation",
  classification: "Taxi & Transportation",
  robots: {
    index: true,
    follow: true,
    nocache: false,
    googleBot: {
      index: true,
      follow: true,
      "max-image-preview": "large",
      "max-snippet": -1,
      "max-video-preview": -1,
    },
  },
  alternates: {
    canonical: "/",
    languages: {
      "nl-NL": "/",
      "en-NL": "/",
      "ar-NL": "/",
    },
  },
  openGraph: {
    title: "HeyCaby — Eerlijk voor chauffeurs. Vertrouwd voor rijders.",
    description:
      "De Nederlandse taxi-app zonder commissie. Chauffeurs houden 100% van hun ritprijs. Rijders reizen veilig van boeking tot afzet.",
    type: "website",
    locale: "nl_NL",
    alternateLocale: ["en_NL", "ar_NL"],
    url: SITE_URL,
    siteName: "HeyCaby",
    images: [
      {
        url: OG_IMAGE,
        width: 1200,
        height: 630,
        alt: "HeyCaby — De taxi-app gebouwd door chauffeurs",
      },
    ],
  },
  twitter: {
    card: "summary_large_image",
    title: "HeyCaby — De taxi-app zonder commissie",
    description:
      "Chauffeurs houden 100% van hun ritprijs. Rijders reizen met zichtbare veiligheid. De Nederlandse taxi-community.",
    images: [OG_IMAGE],
    creator: "@heycaby",
    site: "@heycaby",
  },
  appLinks: {
    ios: {
      url: "https://apps.apple.com/app/id6761512910",
      app_store_id: "6761512910",
    },
    android: {
      package: "nl.heycaby.rider.app",
    },
  },
  manifest: "/site.webmanifest",
  formatDetection: {
    telephone: true,
    address: true,
    email: true,
  },
  other: {
    "apple-app-site-association": "appclips",
    "mobile-web-app-capable": "yes",
    "apple-mobile-web-app-capable": "yes",
    "apple-mobile-web-app-status-bar-style": "default",
    "apple-mobile-web-app-title": "HeyCaby",
  },
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  themeColor: "#F5F5F7",
  colorScheme: "light",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  const organization = {
    "@context": "https://schema.org",
    "@type": "Organization",
    name: "HeyCaby",
    url: SITE_URL,
    areaServed: { "@type": "Country", name: "Netherlands" },
    knowsLanguage: ["nl", "en", "ar"],
    slogan: "Eerlijk voor chauffeurs. Vertrouwd voor rijders.",
    description:
      "Nederlandse taxi-app zonder commissie. Chauffeurs houden 100% van hun ritprijs.",
    sameAs: [
      "https://apps.apple.com/app/id6761512910",
      "https://apps.apple.com/app/id6761512563",
      "https://play.google.com/store/apps/details?id=nl.heycaby.rider.app",
      "https://play.google.com/store/apps/details?id=nl.heycaby.driver.app",
    ],
  };

  const website = {
    "@context": "https://schema.org",
    "@type": "WebSite",
    name: "HeyCaby",
    url: SITE_URL,
    inLanguage: ["nl-NL", "en-NL", "ar-NL"],
    publisher: { "@type": "Organization", name: "HeyCaby" },
  };

  const riderApp = {
    "@context": "https://schema.org",
    "@type": "SoftwareApplication",
    name: "HeyCaby Rider",
    applicationCategory: "TravelApplication",
    operatingSystem: "iOS, Android",
    url: SITE_URL,
    downloadUrl: "https://apps.apple.com/app/id6761512910",
    offers: { "@type": "Offer", price: "0", priceCurrency: "EUR" },
    aggregateRating: {
      "@type": "AggregateRating",
      ratingValue: "5",
      reviewCount: "1",
    },
  };

  const driverApp = {
    "@context": "https://schema.org",
    "@type": "SoftwareApplication",
    name: "HeyCaby Driver",
    applicationCategory: "BusinessApplication",
    operatingSystem: "iOS, Android",
    url: SITE_URL,
    downloadUrl: "https://apps.apple.com/app/id6761512563",
    offers: { "@type": "Offer", price: "0", priceCurrency: "EUR" },
  };

  const service = {
    "@context": "https://schema.org",
    "@type": "Service",
    serviceType: "Taxi service",
    provider: { "@type": "Organization", name: "HeyCaby" },
    areaServed: { "@type": "Country", name: "Netherlands" },
    description:
      "Eerlijke taxi-app zonder commissie. Chauffeurs houden 100% van hun ritprijs. Rijders reizen veilig van boeking tot afzet.",
    offers: { "@type": "Offer", priceCurrency: "EUR" },
  };

  const faq = {
    "@context": "https://schema.org",
    "@type": "FAQPage",
    mainEntity: [
      {
        "@type": "Question",
        name: "Wat is HeyCaby?",
        acceptedAnswer: {
          "@type": "Answer",
          text: "HeyCaby is een Nederlandse taxi-app zonder commissie. Chauffeurs houden 100% van hun ritprijs en rijders reizen met zichtbare veiligheid van boeking tot afzet.",
        },
      },
      {
        "@type": "Question",
        name: "Hoeveel commissie neemt HeyCaby van chauffeurs?",
        acceptedAnswer: {
          "@type": "Answer",
          text: "0%. HeyCaby neemt geen commissie op ritten. Chauffeurs houden 100% van wat de rijder betaalt.",
        },
      },
      {
        "@type": "Question",
        name: "Is HeyCaby veilig voor rijders?",
        acceptedAnswer: {
          "@type": "Answer",
          text: "Ja. HeyCaby maakt elke stap zichtbaar: geverifieerde chauffeur en voertuig, live positie en aankomsttijd, rit delen en veiligheidsacties.",
        },
      },
      {
        "@type": "Question",
        name: "In welke steden is HeyCaby beschikbaar?",
        acceptedAnswer: {
          "@type": "Answer",
          text: "HeyCaby is beschikbaar in heel Nederland, met een focus op Rotterdam en de Randstad.",
        },
      },
      {
        "@type": "Question",
        name: "Wat is Taxi Terug?",
        acceptedAnswer: {
          "@type": "Answer",
          text: "Taxi Terug vult lege kilometers op de terugweg met een rit op jouw route, zodat chauffeurs verdienen ook onderweg naar huis.",
        },
      },
    ],
  };

  return (
    <html lang="nl" suppressHydrationWarning>
      <body>
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(organization) }}
        />
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(website) }}
        />
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(riderApp) }}
        />
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(driverApp) }}
        />
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(service) }}
        />
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(faq) }}
        />
        {children}
      </body>
    </html>
  );
}
