import { defineEnableDraftMode } from "next-sanity/draft-mode";

import { isSanityConfigured } from "@/sanity/lib/api";
import { client } from "@/sanity/lib/client";
import { token } from "@/sanity/lib/token";

const { GET: enableDraftMode } = defineEnableDraftMode({
  client: client.withConfig({ token }),
});

// Draft mode reads unpublished content, so it needs a project and the read
// token. Without either the request cannot be authorised: it is refused like
// a wrong secret (401), with the reason, rather than failing as a 500.
export async function GET(request: Request) {
  if (!isSanityConfigured) {
    return new Response(
      "Draft mode is unavailable: this blog is not connected to a Sanity project yet.",
      { status: 401 },
    );
  }
  if (!token) {
    return new Response(
      "Draft mode is unavailable: set the SANITY_API_READ_TOKEN secret (a Viewer token) to preview drafts.",
      { status: 401 },
    );
  }
  return enableDraftMode(request);
}
