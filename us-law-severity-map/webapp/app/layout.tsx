import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "./globals.css";

const inter = Inter({
  subsets: ["latin"],
  variable: "--font-inter",
});

export const metadata: Metadata = {
  title: "US Law Severity Map | Interactive Visualization",
  description:
    "Interactive map showing law severity scores and crime statistics across the United States. Click any state to explore detailed data.",
  keywords: [
    "law",
    "severity",
    "crime",
    "statistics",
    "US",
    "map",
    "visualization",
  ],
  authors: [{ name: "Law Severity Map Team" }],
  openGraph: {
    title: "US Law Severity Map",
    description:
      "Explore law severity and crime statistics across the United States",
    type: "website",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className="dark">
      <body className={`${inter.variable} font-sans antialiased`}>
        {children}
      </body>
    </html>
  );
}
