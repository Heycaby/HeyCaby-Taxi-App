import type { MetadataRoute } from "next";

export default function sitemap(): MetadataRoute.Sitemap {
  const base = "https://www.heycaby.nl";
  const lastModified = new Date();

  return [
    {
      url: `${base}/`,
      lastModified,
      changeFrequency: "weekly",
      priority: 1.0,
      alternates: {
        languages: {
          "nl-NL": `${base}/`,
          "en-NL": `${base}/`,
          "ar-NL": `${base}/`,
        },
      },
    },
    {
      url: `${base}/support`,
      lastModified,
      changeFrequency: "monthly",
      priority: 0.6,
    },
    {
      url: `${base}/privacy`,
      lastModified,
      changeFrequency: "monthly",
      priority: 0.6,
    },
    {
      url: `${base}/chauffeur/voorwaarden`,
      lastModified,
      changeFrequency: "monthly",
      priority: 0.5,
    },
    {
      url: `${base}/chauffeur/vrijwaring`,
      lastModified,
      changeFrequency: "monthly",
      priority: 0.5,
    },
    {
      url: `${base}/chauffeur/founding-member-contract`,
      lastModified,
      changeFrequency: "monthly",
      priority: 0.4,
    },
  ];
}
