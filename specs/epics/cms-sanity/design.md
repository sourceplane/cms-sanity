# cms-sanity — design

## 1. What the template is

A blog on the App Router whose content is a Sanity dataset. `sanity/lib`
holds the client (`next-sanity`'s `createClient`, API CDN on, stega source
maps pointed at `/studio`), the GROQ queries (`settingsQuery`, `heroQuery`,
`moreStoriesQuery`, `postQuery`, typed by Sanity TypeGen into
`sanity.types.ts`), and `sanityFetch`, which reads `draftMode()` and switches
between the published perspective on the CDN (`revalidate: 60`) and the
`previewDrafts` perspective with the read token (`revalidate: 0`). The
`(blog)` route group renders `/` (intro, hero post, more stories, an
onboarding card when the dataset is empty) and `/posts/[slug]`, with
`VisualEditing` and an alert banner when draft mode is on; a server action
turns it off. `/api/draft-mode/enable` is `next-sanity`'s
`defineEnableDraftMode` over `@sanity/preview-url-secret`. The `(sanity)`
route group mounts the Studio at `/studio/[[...tool]]` (`force-static`) from
`sanity.config.ts`: Presentation (live preview through draft mode),
Structure with a Settings singleton, Unsplash as an asset source, AI Assist
presets, Vision in development. `prebuild` runs `sanity schema extract &&
sanity typegen generate`. Tailwind 3 with the typography plugin, Inter from
`next/font`, `styled-components` for the Studio, Vercel Speed Insights.

## 2. The mapping (Vercel → Cloudflare)

| Vercel primitive the template uses | Here |
|---|---|
| Next.js hosting (ISR pages, a route handler, a server action, the Studio page) | Cloudflare Workers + Static Assets; the Worker is `@opennextjs/cloudflare`'s output; the `(blog)` routes, the draft-mode route and the server action run in it; `/studio` and `/_not-found` come pre-rendered from the static-assets incremental cache |
| `NEXT_PUBLIC_SANITY_PROJECT_ID`, `NEXT_PUBLIC_SANITY_DATASET` from the project's env | Build-time public values: `next build` inlines them into the server bundle and the Studio's chunks. The Orun build exports them from the product's secrets (`apps/web/component.yaml` `secretEnv`); locally `.env.local` (`apps/web/.env.example`). Unset — in Checks, on a fresh clone — the `typegen` and `build` scripts substitute `placeholder`, so the credential-free build runs and the Worker simply has no project until a real build |
| `SANITY_API_READ_TOKEN` from the project's env | A Worker secret, set once per environment with `wrangler secret put` (README → Deploying); `.dev.vars` for `wrangler dev` (`apps/web/.dev.vars.example`); a `build-placeholder` at build time because `sanity/lib/token.ts` asserts it at import and `next build` evaluates the route modules. Nothing at build sends it: no page pre-renders and `generateStaticParams` is gone |
| Time-based ISR (`revalidate: 60` on every published fetch, `generateStaticParams` for the posts) | `dynamic = "force-dynamic"` and `fetchCache = "force-no-store"` on `app/(blog)/layout.tsx`: `/` and `/posts/[slug]` render on every request against Sanity's API CDN (`useCdn: true`), whose 60 s TTL is the interval the ISR matched. `generateStaticParams` and its `postSlugs` query are removed — there is nothing to pre-render, and the call reached Sanity at build |
| Draft mode / live preview (`draftMode()`, `/api/draft-mode/enable`, `VisualEditing`, the `disableDraftMode` action) | Unchanged. Cookies and `fetch` are what they are on Workers; the Presentation tool opens the enable route with its secret and the `__prerender_bypass` cookie flips `sanityFetch` to the drafts perspective with the token. `VisualEditing` is imported from `next-sanity/visual-editing` (where next-sanity 13 exports it) |
| Vercel Visual Editing on preview deployments (`VERCEL_ENV === "preview"` turns stega on outside draft mode) | Never true on Workers; stega is on in draft mode only, which is the Presentation-tool path. Kept as written |
| The embedded Studio (`/studio/[[...tool]]`, `force-static`, `<NextStudio config>` rendered from the page) | Still `force-static`, still `sanity.config.ts` as written. The page renders a client component that loads the Studio with `next/dynamic` and `ssr: false`, and the Studio layout writes out the `metadata`/`viewport` values instead of re-exporting them from `next-sanity/studio`. Both re-exports put the whole `sanity` package into the Worker's server-rendering chunks (31 MB / 7 MB gzip); now the Studio is 10 MB of `_next/static` chunks served as assets and the Worker uploads 7.6 MB / 1.6 MB gzip |
| `sanity schema extract && sanity typegen generate` at `prebuild` | Unchanged (offline, against the schema files); `--force` because sanity 6 refuses to overwrite the committed `schema.json` |
| `styled-components` with `SC_DISABLE_SPEEDY` from `next.config.ts` | Unchanged |
| `@vercel/speed-insights` | `app/(blog)/analytics.tsx`: the Cloudflare Web Analytics beacon (Core Web Vitals included), rendered only when `NEXT_PUBLIC_CF_BEACON_TOKEN` is set |
| Deploy on push | Orun: `apps/web/component.yaml` (`cloudflare-workers-assets-turbo`) builds with the project id and dataset from the product's secrets and deploys `cms-sanity-web-{stage,prod}` on merge to `main` once the product is linked |

Two things changed by the move to Next 16 rather than by Workers, recorded
with the rest: `next-sanity` moves from the 9 line to 13 (the first to
declare `next ^16`), which takes `sanity` to 6 and its plugins along; and
`@sanity/ui` 4 (Studio v6's component library) ships a stylesheet written
with native cascade layers, which Tailwind 3's PostCSS plugin rejects in any
file that lacks its own `@tailwind` directives — so Tailwind 4, CSS-first,
with the template's `tailwind.config.ts` (Inter as the sans family, the
typography plugin, hover only when supported) as a `@theme` block and a
`@plugin` line.

Alternative rejected: keeping ISR with the R2 incremental cache plus the
Durable Object queue and tag cache (the commerce port's shape). It would
let the blog pre-render and revalidate every 60 s as upstream does, at the
price of three bindings and an infrastructure root — for a blog whose data
source is already a CDN with the same TTL, and whose credential-free build
could not pre-render anyway. A product that outgrows one request per page
view can add it without touching the pages: the `dynamic` and `fetchCache`
exports in the `(blog)` layout are the whole change.

Alternative rejected: keeping Tailwind 3 with a PostCSS workaround (Next
refuses a function-form `postcss.config.js`, so the stylesheet could only be
skipped by a plugin of our own that rewrites third-party `@layer` rules).
Tailwind 4 is what Sanity's own Next templates ship with.

## 3. The repository

```
apps/web               the template (app/, sanity/, sanity.config.ts, sanity.cli.ts, schema.json, sanity.types.ts) + the Workers build
  component.yaml       build with turbo (project id + dataset from the product's secrets), deploy, smoke /
  wrangler.jsonc       worker name, nodejs_compat, ASSETS binding — the site binds nothing else
  open-next.config.ts  static-assets incremental cache (pre-rendered /studio and /_not-found)
  .env.example         NEXT_PUBLIC_SANITY_PROJECT_ID, NEXT_PUBLIC_SANITY_DATASET, SANITY_API_READ_TOKEN (next dev), NEXT_PUBLIC_CF_BEACON_TOKEN
  .dev.vars.example    SANITY_API_READ_TOKEN for wrangler dev / preview
tests/web              vitest: urlForImage / resolveOpenGraphImage / resolveHref, DateComponent, GET /api/draft-mode/enable with a mocked client
```

## 4. The build

`pnpm --filter @app/web build` = `prebuild` (`sanity schema extract --force
&& sanity typegen generate`, offline) → `next build` (standalone, traced
from the monorepo root; project id, dataset and token defaulted to
placeholders when unset) → `opennextjs-cloudflare build --skipBuild` →
`opennextjs-cloudflare populateCache local` (copies the pre-rendered
`/studio`, `/_not-found` and the icon routes into the assets bundle). The
build contacts no Sanity API (verified with a fetch guard); `next/font`
fetches Inter from Google Fonts, as upstream.

## 5. Out of scope

The Sanity project itself (created with `pnpm --filter @app/web setup`, as
upstream), a Sanity webhook (this version of the template has no
`/api/revalidate` route and, with the blog dynamic, needs none), image
optimisation through Cloudflare Images (images are Sanity CDN URLs through
`next-sanity/image`'s loader, as upstream), and a custom domain (the
baseline's `cloudflare-domain` root).
