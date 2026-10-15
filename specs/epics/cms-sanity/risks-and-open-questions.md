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

*CS3:* superseded by the unconnected blog (design §6). Neither module
throws; the build script substitutes nothing (the `typegen` script still
does, for the Sanity CLI); a build with no project id — or the old
`placeholder` — renders the bundled sample posts, and never fetches.

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

## CS-G — The read token at module evaluation (RESOLVED in CS3)

`sanity/lib/token.ts` threw when `SANITY_API_READ_TOKEN` was missing, at
import, so a Worker without the secret answered 500 on every blog route and
on the draft-mode route until `wrangler secret put` had run. Upstream
behaves the same on Vercel. A baseline's product is deployed before anyone
can set it, so CS3 makes it optional: the blog renders without it and the
draft-mode route answers 401 with the reason.

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

## CS-J — Sanity is not a provider the platform brokers (RESOLVED in CS3)

A bootstrap cannot create a Sanity project, mint a read token or add a CORS
origin, and the card must not ask for a secret the platform cannot broker.
Resolved by deploying unconnected (design §6): sample posts, a notice, a
connect page, a 401 — and optional secret refs the owner fills later. What
stays the owner's: the project, the two secrets, a redeploy, the CORS
origins, the token.

## CS-K — Setting a secret redeploys nothing (ACCEPTED)

`SANITY_PROJECT_ID` and `SANITY_DATASET` are read when `apps/web` BUILDS,
and `orun plan --changed` plans a component only when its files change. An
owner who stores them sees the samples until the next deploy of `apps/web`.
The README and the operating contract say so, and name the trigger: the
`# orun: redeploy …` line at the end of `apps/web/component.yaml`. Reading
the project id at request time instead would let a secret take effect
without a build, but the Studio's bundle inlines it at build regardless.

## CS-L — A connected blog with a wrong project still answers 500 (ACCEPTED)

Once a project id is set, the blog reads Sanity as upstream does: a wrong id,
a missing dataset or a private dataset without a token is Sanity's error at
request time, a 500 from Next. Masking it behind the samples would show a
connected owner content that is not theirs. The operating contract tells
them to probe `/` after connecting; `02-docs`' record says whether each
environment shows samples or the project's content.

## CS-M — Not proven live (OPEN)

Everything up to the platform is verified offline (IMPLEMENTATION-STATUS):
the blueprint at three orun versions, the offline bootstrap, the product's
own push-to-main plan, every step of the stage lane in a staged job tree,
and the built Worker served and smoke-tested with no Sanity project. Not
proven: a live bootstrap against a workspace (repository creation, the
brokered token, a real deploy and the probes), and a connected blog reading
a real dataset through the Worker (CS-H's Presentation preview included).
