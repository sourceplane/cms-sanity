# cms-sanity

Vercel's [Blog with Sanity CMS](https://github.com/vercel/next.js/tree/canary/examples/cms-sanity)
— posts, authors and settings in a Sanity dataset read over GROQ with
`next-sanity`, draft mode with live preview through the Presentation tool
(unchanged in code; not yet exercised in a browser — risk CS-H),
Sanity TypeGen, AI Assist and Unsplash presets, and the Sanity Studio
embedded at `/studio` — running on **Cloudflare Workers + Static Assets**
through [`@opennextjs/cloudflare`](https://opennext.js.org/cloudflare), and
packaged as an **Orun baseline**: one command takes a new blog from nothing
to live on stage and prod, in its own repository, under its own name, in
ONE landing — before its owner has a Sanity project at all.

The template's code is the code and Sanity stays the SaaS it is. What the
port adds is the Workers build, the monorepo wrapper, a test package and
the deploy contract; what it changes is what Workers force: the blog
renders on request against Sanity's API CDN instead of ISR on a read-only
cache, the Studio mounts client-side so it ships as static assets and not
inside the Worker, and Speed Insights becomes the Cloudflare Web Analytics
beacon. What the baseline adds is everything needed to make a copy of it
somebody else's — built the way
[cirrus-baseline](https://github.com/sourceplane/cirrus-baseline) builds its
product since baseline-v22: one landing, one convergence — and what makes it
deployable with no Sanity project: an unconnected build renders bundled
sample posts under a visible "connect your Sanity project" notice instead of
failing. See [`specs/epics/cms-sanity`](specs/epics/cms-sanity/README.md)
for the design, the milestones and the as-built status.

## Instantiating a blog

```bash
git clone --depth 1 --branch <baseline-tag> https://github.com/sourceplane/cms-sanity
cd cms-sanity
orun new --blueprint repo-blueprint.yaml --out ~/blogs/acme-notes --run-hooks --resume \
  --set reponame=acme-notes --set productname="Acme Notes" \
  --set githuborg=acme-inc --set subdomain=<workers-dev-subdomain>
```

Or, once the platform's registry lists it, from the Orun console (Baselines →
`cms-sanity` → Build). Two phases — `01-product` (the repository, its CI and
the whole blog in one pull request, deployed to stage and prod by one
convergence, smoke-tested) and `02-docs` (the live deployment recorded) —
each landing one pull request in the new repository.
**[BOOTSTRAP.md](BOOTSTRAP.md)** is the operator guide;
[docs/phases/](docs/phases/README.md) has a page per phase.

The new repository receives the **blog only** — the app, its tests, its CI,
its tooling, a README of its own and its operating contract — renamed
throughout to the blog's name, repository and Cloudflare Worker. None of this
repository's machinery ships, and nothing that ships names it.

The only provider the bootstrap asks for is Cloudflare. **Sanity is not a
provider the platform brokers**, so the blog is built without it and its
owner connects a project afterwards: two optional Orun secrets
(`SANITY_PROJECT_ID`, `SANITY_DATASET`) and a redeploy, the Worker URLs in
the project's CORS origins, and — for draft mode only — a Worker secret
`SANITY_API_READ_TOKEN`. The blog's README, "Connecting Sanity"
(`.baseline/product/README.md` here), has the steps.

| What makes it a baseline | Where |
|---|---|
| The console card (inputs, secrets, programme) | `blueprint.yaml` |
| The build document (modules, phases, hooks) | `repo-blueprint.yaml` |
| This tree's identity, and the bootstrap's task contracts | `.baseline/` |
| The rename engine | `tooling/rebrand/rebrand.mjs` |
| The bootstrap's helpers (deferrals, redeploy marker, work-tree strip) | `tooling/bootstrap/` |
| The deployment-record renderer | `hooks/render-deployment-docs.sh` |
| The blog's README and context pack | `.baseline/product/README.md`, `ai/context/` |
| The baseline's tests: contract, leak, offline bootstrap, end to end | `testing/`, `.github/workflows/baseline.yml` |
| Cutting a `baseline-vN` tag | `.github/workflows/tag.yml` |

## What is here (the blog)

| Surface | Where |
|---|---|
| Home, `/posts/[slug]`, the draft-mode banner and action, the unconnected notice | `apps/web/app/(blog)` |
| The Studio at `/studio` (or, unconnected, how to connect) | `apps/web/app/(sanity)`, `apps/web/sanity.config.ts` |
| Draft mode enable route | `apps/web/app/api/draft-mode/enable/route.ts` |
| Client, queries, `sanityFetch`, image URLs, the project configuration | `apps/web/sanity/lib` |
| The sample posts an unconnected blog renders | `apps/web/sanity/lib/sample.ts` |
| Schemas, Studio plugins, generated types | `apps/web/sanity/schemas`, `apps/web/sanity/plugins`, `apps/web/sanity.types.ts` |
| The blog's name (the rename's seam) | `apps/web/app/site.ts` |
| Workers build and deploy contract | `apps/web/next.config.ts`, `open-next.config.ts`, `wrangler.jsonc`, `component.yaml` |
| Tests | `tests/web` (vitest) |

## Getting started

```bash
pnpm install
pnpm typecheck
pnpm lint
pnpm test
pnpm build            # typegen + next build + opennextjs-cloudflare build → apps/web/.open-next
pnpm --filter @app/web preview   # wrangler dev over the built Worker: the sample posts, unconnected
```

That much needs no Sanity project: the baseline's own e2e tier
(`testing/e2e.test.sh`) runs exactly this on each landing before a tag, and
a blog's developers run it before a push — a blog's pull request builds and
dry-deploys it, and does not lint or run the tests. To see your own content:

```bash
cd apps/web
cp .env.example .env.local
pnpm run setup                    # sanity init: picks or creates the project and dataset, writes .env.local
# a Viewer token from manage.sanity.io → API → Tokens, as SANITY_API_READ_TOKEN in .env.local (draft mode only)
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

| Variable | Where it is read | What it does |
|---|---|---|
| `NEXT_PUBLIC_SANITY_PROJECT_ID` | build time (`next build` inlines it into the server bundle and the Studio) | The Sanity project. A deployed build takes it from its environment's `SANITY_PROJECT_ID` secret, best-effort. Unset, the blog is unconnected: the sample posts under a notice, a connect page at `/studio`, draft mode refused with 401. |
| `NEXT_PUBLIC_SANITY_DATASET` | build time | The dataset (`SANITY_DATASET`); `production` when unset. |
| `SANITY_API_READ_TOKEN` | request time, in the Worker | A Viewer token; draft mode and live preview fetch drafts with it. A Worker secret in stage/prod, `.dev.vars` locally, `.env.local` for `next dev`. Optional: without it the blog renders and draft mode answers 401 with the reason. |
| `NEXT_PUBLIC_CF_BEACON_TOKEN` | build time | Optional. Cloudflare Web Analytics token (dashboard → Web Analytics → add a site). Unset, no script is rendered. |

## How it maps to Vercel

| Vercel | Here |
|---|---|
| Next.js hosting (ISR pages, route handler, server action, Studio page) | One Cloudflare Worker (`.open-next/worker.js`) + Static Assets; `/` and `/posts/[slug]` render on every request (`force-dynamic`), `/studio` is a pre-rendered shell from the static-assets cache |
| Project env vars in the dashboard | Build time: project id and dataset from optional Orun secrets, inlined by `next build`. Run time: the read token as a Worker secret |
| A missing env var fails every route | An unconnected blog: sample posts, a notice, a connect page — deployable before a Sanity project exists |
| Time-based ISR (`revalidate: 60`) | Sanity's API CDN, same 60 s TTL; nothing is pre-rendered or revalidated in the Worker |
| Draft mode / Presentation live preview | Unchanged in code (`/api/draft-mode/enable`, cookies, `VisualEditing`); not yet exercised in a browser against a Sanity project — risk CS-H |
| The Studio rendered on the server | Loaded client-side only; megabytes of static chunks, a small Worker |
| Vercel Speed Insights | Cloudflare Web Analytics beacon (`app/(blog)/analytics.tsx`) |
| Deploy on push | Orun deploys `<repo>-web-{stage,prod}` on merge to `main` and smoke-tests it (`apps/web/component.yaml`) |
| "Deploy with Vercel" (clone the template) | `orun new --blueprint repo-blueprint.yaml` — a new repository, branded, deployed |

## CI

| Workflow | What it runs | Ships to a blog |
|---|---|---|
| `ci.yml` | the Orun pipeline, and the only workflow a blog carries: `orun plan --changed`, then one job per lane. A pull request runs the verify lanes (the blog built and dry-deployed per environment; they do not lint or run the tests), except the bootstrap's own landings (`orun/BASE-*`), where `plan` alone is the check; a merge deploys stage → prod. It plans nothing while `intent.yaml` names the placeholder workspace `ws_CHANGE_ME`, as this repository does | yes |
| `baseline.yml` | the baseline's own tiers: contract tests and the component docs' drift check, the blueprint read by the pinned orun, the leak gate, the offline bootstrap, each landing installed, its fixture rendered, type-checked, linted, tested and built, then the blog built in a staged job tree, dry-deployed and served with no Sanity project | no |
| `tag.yml` | cuts a `baseline-vN` tag (manual) | no |
