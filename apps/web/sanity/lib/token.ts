import "server-only";

/**
 * The Viewer token draft mode and live preview fetch drafts with. Read at
 * request time: a Worker secret in a deployed environment, `.dev.vars` under
 * `wrangler dev`, `.env.local` under `next dev`.
 *
 * Optional. Published content is read from Sanity's API CDN without it, so the
 * blog renders either way; only draft mode needs it, and the draft-mode route
 * answers 401 with the reason when it is missing. Upstream throws here, which
 * made every route a 500 until the token was set.
 */
export const token: string | undefined =
  process.env.SANITY_API_READ_TOKEN?.trim() || undefined;
