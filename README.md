# cms-sanity

Vercel's [Blog with Sanity CMS](https://github.com/vercel/next.js/tree/canary/examples/cms-sanity)
— posts, authors and settings in a Sanity dataset read over GROQ with
`next-sanity`, draft mode with live preview through the Presentation tool,
Sanity TypeGen, AI Assist and Unsplash presets, and the Sanity Studio
embedded at `/studio` — running on **Cloudflare Workers + Static Assets**
through [`@opennextjs/cloudflare`](https://opennext.js.org/cloudflare),
inside the repository conventions of the
[Cirrus baseline](https://github.com/sourceplane/cirrus-baseline).

The template's code is the code and Sanity stays the SaaS it is. What the
port adds is the Workers build, the monorepo wrapper, a test package and
the deploy contract; what it changes is what Workers force: the blog
renders on request against Sanity's API CDN instead of ISR on a read-only
cache, the Studio mounts client-side so it ships as static assets and not
inside the Worker, and Speed Insights becomes the Cloudflare Web Analytics
beacon. See [`specs/epics/cms-sanity`](specs/epics/cms-sanity/README.md)
for the design, the milestones and the as-built status.

## What is here

| Surface | Where |
|---|---|
| Home, `/posts/[slug]`, the draft-mode banner and action | `apps/web/app/(blog)` |
| The Studio at `/studio` | `apps/web/app/(sanity)`, `apps/web/sanity.config.ts` |
| Draft mode enable route | `apps/web/app/api/draft-mode/enable/route.ts` |
| Client, queries, `sanityFetch`, image URLs | `apps/web/sanity/lib` |
| Schemas, Studio plugins, generated types | `apps/web/sanity/schemas`, `apps/web/sanity/plugins`, `apps/web/sanity.types.ts` |
| Workers build and deploy contract | `apps/web/next.config.ts`, `open-next.config.ts`, `wrangler.jsonc`, `component.yaml` |
| Tests | `tests/web` (vitest) |

## Getting started

```bash
pnpm install
pnpm typecheck
pnpm lint
pnpm test
pnpm build            # typegen + next build + opennextjs-cloudflare build → apps/web/.open-next
```

That much needs no Sanity project: the build substitutes placeholder values
for the project id, dataset and token when they are unset (`Checks` runs
exactly this). To see content you need a project:

```bash
cd apps/web
cp .env.example .env.local
pnpm run setup                    # sanity init: picks or creates the project and dataset, writes .env.local
# then create a Viewer token at manage.sanity.io → API → Add API token and put it in .env.local as SANITY_API_READ_TOKEN
cd ../..
pnpm --filter @app/web dev        # http://localhost:3000, the Studio at /studio
```

For the Worker locally, the project id and dataset are read at build time
and the token is a Worker secret:

```bash
cd apps/web
cp .dev.vars.example .dev.vars    # SANITY_API_READ_TOKEN=<the same Viewer token>
NEXT_PUBLIC_SANITY_PROJECT_ID=<id> NEXT_PUBLIC_SANITY_DATASET=<dataset> pnpm build
pnpm preview                      # wrangler dev over the built Worker
```

Variables (`apps/web/.env.example`, `apps/web/.dev.vars.example`):

| Variable | Where it is read | What it does |
|---|---|---|
| `NEXT_PUBLIC_SANITY_PROJECT_ID`, `NEXT_PUBLIC_SANITY_DATASET` | build time (`next build` inlines them into the server bundle and the Studio) | The Sanity project and dataset. The Orun build exports them from the product's secrets; unset, the build uses `placeholder` for both and the Worker has no project to read from. |
| `SANITY_API_READ_TOKEN` | request time, in the Worker | A Viewer token; draft mode and live preview fetch drafts with it. A Worker secret in stage/prod, `.dev.vars` locally, `.env.local` for `next dev`. Without it every blog route answers 500 (`Missing SANITY_API_READ_TOKEN`), as upstream. |
| `NEXT_PUBLIC_CF_BEACON_TOKEN` | build time | Optional. Cloudflare Web Analytics token (dashboard → Web Analytics → add a site). Unset, no script is rendered. |

Content: open `/studio`, create a post (the home page shows an onboarding
card until one exists), publish it. The blog reads Sanity's API CDN on every
request, so a published change shows within its 60 s TTL.

## How it maps to Vercel

| Vercel | Here |
|---|---|
| Next.js hosting (ISR pages, route handler, server action, Studio page) | One Cloudflare Worker (`.open-next/worker.js`) + Static Assets; `/` and `/posts/[slug]` render on every request (`force-dynamic`), `/studio` is a pre-rendered shell from the static-assets cache |
| Project env vars in the dashboard | Build time: project id and dataset from Orun secrets, inlined by `next build`. Run time: the read token as a Worker secret |
| Time-based ISR (`revalidate: 60`) | Sanity's API CDN, same 60 s TTL; nothing is pre-rendered or revalidated in the Worker |
| Draft mode / Presentation live preview | Unchanged (`/api/draft-mode/enable`, cookies, `VisualEditing`) |
| The Studio rendered on the server | Loaded client-side only; 10 MB of static chunks, a 1.6 MB gzip Worker |
| Vercel Speed Insights | Cloudflare Web Analytics beacon (`app/(blog)/analytics.tsx`) |
| Deploy on push | Orun deploys `cms-sanity-web-{stage,prod}` on merge to `main` (`apps/web/component.yaml`) |

## Deploying

`.github/workflows/checks.yml` runs install, typecheck, lint, test and build
on every push and pull request, with no Sanity credentials. `ci.yml` is the
Orun pipeline: set `execution.state.workspace` in `intent.yaml` to this
product's workspace (`orun cloud link`), connect a Cloudflare account to it,
and set the `ORUN_CI` repository variable to `true`. A merge to `main` then
builds the app with that environment's project id and dataset and deploys
the Worker to `stage`, then `prod`.

Three things are the product's to set once per environment:

```bash
# Build-time values, read by apps/web/component.yaml's secretEnv at build
# (each prompts for its value)
orun secrets set SANITY_PROJECT_ID --env stage    # the project id from manage.sanity.io
orun secrets set SANITY_DATASET    --env stage    # usually "production"

# The Worker secret (the deploy lane does not set it)
wrangler secret put SANITY_API_READ_TOKEN --name cms-sanity-web-stage   # a Viewer token
```

Then, in the Sanity project's settings (manage.sanity.io → API → CORS
origins), allow the Worker's origin with credentials so the embedded Studio
can talk to the dataset from `https://cms-sanity-web-prod.<subdomain>.workers.dev/studio`.
