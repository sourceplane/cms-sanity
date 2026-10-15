"use client";

import dynamic from "next/dynamic";

// The Studio is a browser application. Upstream renders <NextStudio> straight
// from the page, which puts the whole `sanity` package into the server-side
// rendering chunks — on Vercel a cost nobody sees, on a Worker megabytes of
// bundle for a page that only ever draws a spinner on the server. Loading it
// client-side only keeps the Studio in the static assets and out of the
// Worker bundle.
const NextStudio = dynamic(() => import("./studio-client"), { ssr: false });

export default function Studio() {
  return <NextStudio />;
}
