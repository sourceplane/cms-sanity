/**
 * As this file is reused in several other files, try to keep it lean and small.
 * Importing other npm packages here could lead to needlessly increasing the client bundle size, or end up in a server-only function that don't need it.
 */

/**
 * The Sanity project the blog reads, and whether there is one.
 *
 * Both values are public and read at BUILD time: `next build` inlines
 * `NEXT_PUBLIC_*` into the server and the Studio bundles. A build without a
 * project id is a blog that is not connected yet, not a broken one: it renders
 * the bundled sample posts (sanity/lib/sample.ts) under a visible "connect your
 * Sanity project" notice, and /studio says how to connect instead of opening a
 * Studio that has nothing to talk to. Upstream throws here instead, which made
 * every route of a fresh deploy a 500.
 *
 * `placeholder` is what earlier builds substituted for a missing id; it counts
 * as no project. The dataset defaults to `production`, Sanity's own default.
 */
const configuredProjectId = process.env.NEXT_PUBLIC_SANITY_PROJECT_ID?.trim() ?? "";

export const isSanityConfigured =
  configuredProjectId !== "" && configuredProjectId !== "placeholder";

// The client and the Studio refuse an empty project id, so an unconnected
// build still hands them a syntactically valid one; nothing is fetched with it.
export const projectId = isSanityConfigured ? configuredProjectId : "placeholder";

export const dataset =
  process.env.NEXT_PUBLIC_SANITY_DATASET?.trim() || "production";

/**
 * see https://www.sanity.io/docs/api-versioning for how versioning works
 */
export const apiVersion =
  process.env.NEXT_PUBLIC_SANITY_API_VERSION || "2024-02-28";

/**
 * Used to configure edit intent links, for Presentation Mode, as well as to configure where the Studio is mounted in the router.
 */
export const studioUrl = "/studio";
