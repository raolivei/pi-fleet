import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Disable the built-in dev overlay in production
  devIndicators: {
    appIsrStatus: false,
  },
  
  // Production optimizations
  reactStrictMode: true,
  
  // Disable telemetry collection
  telemetry: false,

  // Image optimization
  images: {
    unoptimized: true,
  },
};

export default nextConfig;
