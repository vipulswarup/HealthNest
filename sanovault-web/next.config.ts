import type { NextConfig } from "next";

const securityHeaders = [
  {
    key: "Content-Security-Policy",
    value: [
      "default-src 'self'",
      "base-uri 'self'",
      "object-src 'none'",
      "form-action 'self'",
      "frame-ancestors 'none'",
      "script-src 'self' 'unsafe-inline'",
      "style-src 'self' 'unsafe-inline'",
      "img-src 'self' data: blob: https://*.r2.cloudflarestorage.com",
      "font-src 'self' data:",
      "connect-src 'self'",
      "frame-src 'self' blob: https://*.r2.cloudflarestorage.com",
    ].join("; "),
  },
  { key: "X-Content-Type-Options", value: "nosniff" },
  { key: "X-Frame-Options", value: "DENY" },
  { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
  {
    key: "Permissions-Policy",
    value: "camera=(self), geolocation=(), microphone=(), payment=(), usb=()",
  },
  { key: "X-DNS-Prefetch-Control", value: "off" },
  { key: "X-Permitted-Cross-Domain-Policies", value: "none" },
];

const nextConfig: NextConfig = {
  // This repository is nested under an asset repository with its own lockfile.
  // Pin Turbopack to this application so dependency and environment discovery is deterministic.
  turbopack: {
    root: __dirname,
  },
  // Keep libheif's WebAssembly loader intact in server functions. Bundling it
  // triggers a dynamic-require warning and is unnecessary for this Node-only path.
  serverExternalPackages: ['heic-convert'],
  async headers() {
    return [
      {
        source: "/(.*)",
        headers: securityHeaders,
      },
    ];
  },
};

export default nextConfig;
