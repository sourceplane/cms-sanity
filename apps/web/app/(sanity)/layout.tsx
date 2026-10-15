import "../globals.css";

import type { Metadata, Viewport } from "next";
import { Inter } from "next/font/google";

const inter = Inter({
  variable: "--font-inter",
  subsets: ["latin"],
  display: "swap",
});

// The values `next-sanity/studio` exports as `metadata` and `viewport`,
// written out: re-exporting them imports the Studio's client component into
// this layout and, with it, the whole `sanity` package into the Worker's
// server-rendering chunks (see studio/[[...tool]]/studio.tsx).
export const metadata: Metadata = { referrer: "same-origin", robots: "noindex" };
export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  viewportFit: "cover",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" className={inter.variable}>
      <body className="min-h-screen">{children}</body>
    </html>
  );
}
