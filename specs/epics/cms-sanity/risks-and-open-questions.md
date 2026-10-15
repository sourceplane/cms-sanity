# cms-sanity — risks and open questions

## CS-A — ISR on a read-only cache (RESOLVED)

Upstream pre-renders the blog and revalidates every fetch after 60 s. The
static-assets incremental cache cannot revalidate (every write is refused
and logged), and a build without a Sanity project cannot pre-render at all.
`app/(blog)/layout.tsx` exports `dynamic = "force-dynamic"` and `fetchCache
= "force-no-store"`: every blog request goes to Sanity's API CDN, whose
60 s TTL is what the ISR interval was chosen to match. Next 16 would
otherwise keep an explicit fetch-level `revalidate: 60` under
`force-dynamic` and try the data cache on every request; `force-no-store`
is what stops that. The R2 + Durable Object caches (commerce's shape) are
the fallback if a product needs fewer origin requests (`design.md` §2).

## CS-B — The Studio in the Worker bundle (RESOLVED)

`next-sanity/studio`'s `NextStudio` loads the Studio with `React.lazy` +
`Suspense` (its source says it would use `next/dynamic` with `ssr: false`
if the App Router on Turbopack allowed it), so rendering it from the page —
and even re-exporting `metadata`/`viewport` from `next-sanity/studio` in
the Studio layout — puts the whole `sanity` package into the server-side
rendering chunks: 31 MB uploaded, 7 MB gzip, above the free plan's limit.
The page now renders a client component that loads the Studio through
`next/dynamic` with `ssr: false`, and the layout writes the two metadata
values out. 7.6 MB uploaded, 1.6 MB gzip, and the Studio HTML is the same
shell with the same `noindex`.

## CS-C — Tailwind 3 and Studio v6's stylesheet (RESOLVED)

`@sanity/ui` 4 ships `styles.css` with `@layer tokens` and `@layer
utilities` — native cascade layers — and Tailwind 3's PostCSS plugin reads
the second as its own directive and fails any file that has it without
`@tailwind utilities`. The file is imported by `sanity` and by the Unsplash
plugin, Next refuses a function-form PostCSS config, so Tailwind 4
(`@tailwindcss/postcss`, which leaves foreign `@layer` alone). The
template's config is three lines of CSS; Tailwind 3's default border colour
is restored in `@layer base` so the footer's `border-t` looks the same.

## CS-D — A credential-free build (RESOLVED)

`sanity/lib/api.ts` throws at import without the project id and dataset
(the Sanity CLI's `schema extract` loads it too), `sanity/lib/token.ts`
throws without the read token, and `next build` evaluates every route
module. The `typegen` and `build` scripts default the three to
`placeholder` / `build-placeholder` when unset. With the blog dynamic and
`generateStaticParams` gone nothing fetches at build; a `fetch` guard that
fails on any `sanity.io` URL ran the whole build green. The placeholders
are the Worker's values only if a deploy build forgets to export the real
ones — then every blog route answers 500 with Sanity's "Dataset not found".

## CS-E — next-sanity 9 → 13, sanity 3 → 6 (RESOLVED)

The template floats `next-sanity ^9.7` (peer `next ^14 || ^15`) and
`sanity ^3.62`. The adapter's floor is Next 16, which only `next-sanity`
13 declares; its peers take `sanity` to 6, `@sanity/vision`, `@sanity/assist`
and the Unsplash plugin along, and make `@sanity/client` a peer the app
installs itself. Three API moves: `VisualEditing` from
`next-sanity/visual-editing`; `sanity schema extract --force` (6 refuses to
overwrite a committed `schema.json`); TypeGen 6's output format for
`schema.json` and `sanity.types.ts` (regenerated, committed as generated).
`@sanity/client` 8 prints a deprecation for the `previewDrafts` perspective
(`drafts` is the new name); it still works and the fetch is kept as written.

## CS-F — Speed Insights has no one-to-one twin (ACCEPTED)

Cloudflare Web Analytics reports Core Web Vitals, which is what Speed
Insights showed; the dashboard differs. The beacon is opt-in by token.

## CS-G — The read token at module evaluation (ACCEPTED)

`sanity/lib/token.ts` throws when `SANITY_API_READ_TOKEN` is missing, at
import, so a Worker without the secret answers 500 on every blog route and
on the draft-mode route until `wrangler secret put` has run (locally:
`.dev.vars`). Upstream behaves the same on Vercel; the README says so.

## CS-H — Draft-mode cookies inside the Presentation iframe (OPEN)

`next-sanity` 13 sets the draft-mode cookies with `SameSite=None;
Partitioned` when the enable route is opened cross-site in an iframe and
`NODE_ENV` is production, which a `workers.dev` origin is. The route is
exercised by the tests with a mocked client (401, 307 + cookie), not by a
browser against a Sanity project: the first product to link one should open
the Presentation tool once and confirm the preview loads.

## CS-I — The upstream perspective precedence (ACCEPTED)

`sanityFetch` reads `_perspective || isEnabled ? "previewDrafts" :
"published"`, which makes an explicit `perspective: "published"` select
drafts (and the token). Only `generateStaticParams` passed one, and it is
gone; the line is kept as upstream wrote it.
