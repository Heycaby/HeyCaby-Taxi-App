import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  output: "standalone",
  images: { formats: ["image/avif", "image/webp"] },
  async rewrites() {
    return {
      beforeFiles: [],
      afterFiles: [],
      fallback: [
        // Local source-controlled API routes (notably /api/shared-ride) must
        // win. Unimplemented mobile compatibility endpoints still fall back
        // to the legacy backend until their callers are formally retired.
        {
          source: "/api/:path*",
          destination: "https://rydtap-web-app.vercel.app/api/:path*",
        },
      ],
    };
  },
};

export default nextConfig;
