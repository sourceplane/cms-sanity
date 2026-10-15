import { isSanityConfigured } from "@/sanity/lib/api";

import ConnectStudio from "./connect";
import Studio from "./studio";

export const dynamic = "force-static";

export default function StudioPage() {
  // Decided at build time: the project id is inlined by `next build`.
  return isSanityConfigured ? <Studio /> : <ConnectStudio />;
}
