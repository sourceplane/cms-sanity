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
| Draft mode / live preview (`draftMode()`, `/api/draft-mode/enable`, `VisualEditing`, the `disableDraftMode` action) | Unchanged. Cookies and `fetch` are what they are on Workers; the Presentation tool opens the enable route with its secret and the `__prerender_bypass` cookie flips `sanityFetch` to the drafts perspective with the token. `VisualEditing` is imported from `next-sanity/visual-editing` (where next-sanity 13 exports it). Unchanged in code; not yet exercised in a browser against a Sanity project (risk CS-H) |
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
  component.yaml       build with turbo (project id + dataset from the product's secrets, best-effort), deploy, smoke / + the draft-mode 401
  wrangler.jsonc       worker name, nodejs_compat, ASSETS binding — the site binds nothing else
  open-next.config.ts  static-assets incremental cache (pre-rendered /studio and /_not-found)
  .env.example         NEXT_PUBLIC_SANITY_PROJECT_ID, NEXT_PUBLIC_SANITY_DATASET, SANITY_API_READ_TOKEN (next dev), NEXT_PUBLIC_CF_BEACON_TOKEN
  .dev.vars.example    SANITY_API_READ_TOKEN for wrangler dev / preview
tests/web              vitest: urlForImage / resolveOpenGraphImage / resolveHref, DateComponent, GET /api/draft-mode/enable with a mocked client,
                       the unconnected blog (sample answers, no Sanity call, draft mode's 401s), the site-name seam
```

## 4. The build

`pnpm --filter @app/web build` = `prebuild` (`sanity schema extract --force
&& sanity typegen generate`, offline) → `next build` (standalone, traced
from the monorepo root; with no project id the build is the unconnected
blog, §6) → `opennextjs-cloudflare build --skipBuild` →
`opennextjs-cloudflare populateCache local` (copies the pre-rendered
`/studio`, `/_not-found` and the icon routes into the assets bundle). The
build contacts no Sanity API (verified with a fetch guard); `next/font`
fetches Inter from Google Fonts, as upstream.

## 5. Out of scope

The Sanity project itself (created with `pnpm --filter @app/web setup`, as
upstream), a Sanity webhook (this version of the template has no
`/api/revalidate` route and, with the blog dynamic, needs none), image
optimisation through Cloudflare Images (images are Sanity CDN URLs through
`next-sanity/image`'s loader, as upstream), and a custom-domain component
(§6: the brokered deploy token carries no zone permissions, so attaching a
domain is the owner's step).

## 6. The baseline (CS3)

The repository instantiates new blogs the way
[cirrus-baseline](https://github.com/sourceplane/cirrus-baseline) instantiates
its product since baseline-v22: a console card (`blueprint.yaml`) the platform
renders, a build document (`repo-blueprint.yaml`) `orun new` runs, and a
rename engine that makes the copy somebody else's. What a small-site
baseline contains is portfolio-starter-kit's (baseline-v2); how the build
runs is cirrus's — ONE landing; the no-infra shape is hono-api's (HA3).

| portfolio-starter-kit | Here | Why the difference |
|---|---|---|
| three phases: `01-scaffold`, `02-site`, `03-docs` | two: `01-product`, `02-docs` | cirrus-baseline v22: a landing has a fixed cost, and nothing here needs the scaffold merged before the app |
| the brokered secrets reconciled in `02-site`'s `pre` | in `01-product`'s `post`, after `repo` and `link`, before `land` | cirrus's 01-product |
| `SITE_NAME` + `SOURCE_URL` in `apps/web/app/site.ts` | `SITE_NAME` alone | the blog's name is the fallback for the Settings document's title; the one GitHub link (the footer's "View on GitHub") is the upstream template's, and stays |
| `SITE_URL` per environment | none | the blog renders no absolute link to itself; Open Graph images are Sanity CDN URLs |
| smoke: the home page's nav and the feed | smoke: the home page's layout, and the draft-mode route's 401 | the name is the owner's to change; the 401 is server code, which only the Worker answers |
| all content in the repository | content in the owner's Sanity project, connected AFTER the bootstrap | Sanity is not a provider the platform brokers (below) |

**A blog that deploys before Sanity exists.** The platform brokers
Cloudflare, not Sanity: no bootstrap can create a Sanity project or mint its
token, and the card asks for no secret the platform cannot broker. Upstream,
a build without a project id throws at import (`sanity/lib/api.ts`) and a
Worker without the read token answers 500 on every route
(`sanity/lib/token.ts`). Here neither throws:

- `api.ts` exports `isSanityConfigured` — a project id is set, and is not the
  `placeholder` earlier builds substituted. The dataset defaults to
  `production`.
- Unconnected, `sanityFetch` answers the four queries from
  `sanity/lib/sample.ts` — three posts typed by the TypeGen result types, the
  first of which says how to connect — and never calls the client. The blog
  layout shows a "Sample content … Connect your Sanity project" notice
  (`data-sanity-notice="unconnected"`), `/studio` renders a connect page
  instead of a Studio pointed at no project, and the draft-mode route answers
  401 with the reason. Nothing is a 500.
- The token is optional (`token.ts` exports `undefined`): published content
  needs none; draft mode answers 401 without it.
- `apps/web/component.yaml` reads `SANITY_PROJECT_ID` and `SANITY_DATASET`
  through `optionalSecretEnv` (cirrus's wire-now-seed-later shape): a key
  nobody has stored is skipped when the job resolves its secrets. Owners set
  them per environment with `orun secrets set` and redeploy; the read token
  is a Worker secret (`wrangler secret put`), which a deploy never touches.
  The product's README, "Connecting Sanity", has the steps, CORS included.

The upstream demo (`next-blog.sanity.build`) reads a public dataset
(`r0z1eifg/blog-vercel`, which answered a public GROQ query on 2026-10-15),
but the template does not read it by default — it needs the env vars — and a
product reading another party's demo content is neither the owner's blog nor
under anyone's control here. Bundled samples are deterministic, offline and
the product's own.

**The Worker's config stays committed.** The composition's
`verify-app-structure` step runs `test -f package.json` and
`test -f wrangler.jsonc` before any build, in the tree the runner stages;
`wrangler.jsonc` is committed (it binds only `ASSETS`), never generated.

**stack-tectonic 0.19.0.** 0.20.0's lane-scoped install links the job tree's
`node_modules` out of the tree, and Next 16's Turbopack refuses it.

**Testing without the platform, or Sanity.** `testing/lib/bootstrap.sh`
places both phases and runs the blueprint's own `run:` hooks on top of
orun's empty `Initial commit`; `testing/placement.test.sh` plans the
product's push-to-main exactly as `ci.yml` does and asserts the Sanity refs
are optional; `testing/e2e.test.sh` runs every step of the stage lane's
pull-request plan in a job tree staged as orun stages it, with no Sanity
credentials, serves the Worker with `wrangler dev`, runs the component's own
smoke, and reads every route.
