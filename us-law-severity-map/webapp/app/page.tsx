"use client";

import dynamic from "next/dynamic";

// Dynamic import to avoid SSR issues with Mapbox
const InteractiveMap = dynamic(() => import("@/components/InteractiveMap"), {
  ssr: false,
  loading: () => (
    <div className="w-full h-screen flex items-center justify-center bg-gray-900">
      <div className="text-center">
        <div className="w-16 h-16 border-4 border-blue-500 border-t-transparent rounded-full animate-spin mx-auto mb-4" />
        <p className="text-white text-xl font-semibold">Loading Map...</p>
      </div>
    </div>
  ),
});

export default function Home() {
  return <InteractiveMap />;
}
