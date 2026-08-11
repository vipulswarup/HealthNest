import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // This repository is nested under an asset repository with its own lockfile.
  // Pin Turbopack to this application so dependency and environment discovery is deterministic.
  turbopack: {
    root: __dirname,
  },
};

export default nextConfig;
