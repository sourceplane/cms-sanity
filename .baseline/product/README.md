# cms-sanity

A blog whose posts, authors and settings live in a [Sanity](https://www.sanity.io)
dataset — read over GROQ with `next-sanity`, with draft mode and live preview
through Sanity's Presentation tool, and the Sanity Studio embedded at
`/studio` — running on **Cloudflare Workers + Static Assets** through
[`@opennextjs/cloudflare`](https://opennext.js.org/cloudflare). It is
Vercel's [Blog with Sanity CMS](https://github.com/vercel/next.js/tree/canary/examples/cms-sanity)
template, ported to Workers.

## Live deployment

<!-- 02-docs:begin -->
Not recorded yet. The bootstrap's last phase writes the live URLs, the
workspace and the secrets the blog uses into
[ai/context/deployment.md](ai/context/deployment.md); how the blog deploys
and how to operate it is in
[ai/context/operations.md](ai/context/operations.md).
<!-- 02-docs:end -->

## Connecting Sanity

The blog deploys and serves before it has a Sanity project: until its build
is given a project id it shows a few **sample posts** bundled with it, under
a notice that says so, and `/studio` explains how to connect instead of
opening a Studio with nothing behind it. To make it read your content:

1. **Create a project** at [sanity.io/manage](https://www.sanity.io/manage)
   (or `cd apps/web && pnpm run setup`, which runs `sanity init`). Note the
   project id and the dataset — usually `production`.
2. **Give the build your project**, once per deployed environment. Both are
   public values `next build` bakes in, stored as this repository's Orun
   secrets so stage and prod can each name their own:

   ```bash
   orun secrets set SANITY_PROJECT_ID --env stage   # prompts for the value
   orun secrets set SANITY_DATASET    --env stage   # optional: production when unset
   orun secrets set SANITY_PROJECT_ID --env prod
   orun secrets set SANITY_DATASET    --env prod
   ```

   Then **redeploy the blog**: a secret is read when the blog builds, and
   setting one builds nothing. Change the stamp on the last line of
   `apps/web/component.yaml` (`# orun: redeploy …`) and merge; the sample
   posts and the notice are gone from that deploy on.
3. **Allow the site's origins** in the project (API → CORS origins):
   `https://cms-sanity-web-stage.your-workers-subdomain.workers.dev`,
   `https://cms-sanity-web-prod.your-workers-subdomain.workers.dev` and any
   custom domain, each **with credentials allowed** — the Studio signs in
   from them.
4. **Add a read token for draft mode** (optional; published posts need
   none). Create a Viewer token (API → Tokens) and store it as a Worker
   secret in each environment — Cloudflare's, so deploys leave it alone:

   ```bash
   pnpm --filter @app/web exec wrangler secret put SANITY_API_READ_TOKEN --name cms-sanity-web-stage
   pnpm --filter @app/web exec wrangler secret put SANITY_API_READ_TOKEN --name cms-sanity-web-prod
   ```

   Without it the Studio's live preview is refused (the draft-mode route
   answers 401 and says why); everything else works. With it, open the
   Presentation tool once and confirm the preview loads: the draft-mode
   cookies it relies on inside the Studio's iframe (`SameSite=None;
   Partitioned`) are tested with a mocked client, not yet in a browser.

Then write at `/studio`. Published changes show on the blog within a minute
(Sanity's API CDN cache) — no deploy.

## What is here

| Surface | Where |
|---|---|
| Home, `/posts/[slug]`, the draft-mode banner and action | `apps/web/app/(blog)` |
| The Studio at `/studio` | `apps/web/app/(sanity)`, `apps/web/sanity.config.ts` |
| Draft mode enable route | `apps/web/app/api/draft-mode/enable/route.ts` |
| Client, queries, `sanityFetch`, image URLs | `apps/web/sanity/lib` |
| The sample posts an unconnected blog shows | `apps/web/sanity/lib/sample.ts` |
| Schemas, Studio plugins, generated types | `apps/web/sanity/schemas`, `apps/web/sanity/plugins`, `apps/web/sanity.types.ts` |
| The blog's name until its Settings document gives one | `apps/web/app/site.ts` |
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

That needs no Sanity project, and is what to run before you push: a pull
request builds the blog but does not lint or run its tests. With a project:

```bash
cd apps/web
cp .env.example .env.local        # NEXT_PUBLIC_SANITY_PROJECT_ID, NEXT_PUBLIC_SANITY_DATASET, SANITY_API_READ_TOKEN
cd ../..
pnpm --filter @app/web dev        # http://localhost:3000, the Studio at /studio
```

For the Worker locally, the project id and dataset are read at build time
and the token is a Worker secret:

```bash
cd apps/web
cp .dev.vars.example .dev.vars    # SANITY_API_READ_TOKEN=<a Viewer token>
NEXT_PUBLIC_SANITY_PROJECT_ID=<id> NEXT_PUBLIC_SANITY_DATASET=<dataset> pnpm build
pnpm preview                      # wrangler dev over the built Worker
```

| Variable | Read | What it does |
|---|---|---|
| `NEXT_PUBLIC_SANITY_PROJECT_ID` | build time | The Sanity project. Deployed builds take it from the `SANITY_PROJECT_ID` secret of their environment. Unset, the blog is unconnected: sample posts and a notice. |
| `NEXT_PUBLIC_SANITY_DATASET` | build time | The dataset (`SANITY_DATASET`); `production` when unset. |
| `SANITY_API_READ_TOKEN` | request time, in the Worker | A Viewer token for draft mode and live preview. Optional. |
| `NEXT_PUBLIC_CF_BEACON_TOKEN` | build time | Optional Cloudflare Web Analytics token. Unset, no script is rendered. |

## How it deploys

Merges to `main` converge through [Orun](https://github.com/sourceplane/orun):
`.github/workflows/ci.yml` plans the changed components and runs each lane
against the workspace in `intent.yaml`. The blog builds once per
environment, with that environment's Sanity project, and deploys — to
`stage`, then to `prod` once stage has converged on the same commit; `dev`
only verifies. The Worker is `cms-sanity-web-<env>` on your account's
workers.dev subdomain, and every deploy is smoke-tested over HTTP: the home
page must render and the draft-mode route must refuse a request without a
preview secret. A pull request runs the same pipeline's verify lanes: the
blog built and dry-deployed for each environment, with nothing deployed.
They do not lint or run the tests, so run `pnpm typecheck`, `pnpm lint` and
`pnpm test` before you push. (A push to `main` builds, deploys and
smoke-tests.)

The pipeline holds one credential, GitHub's own `GITHUB_TOKEN`. The
Cloudflare token and account id are brokered per run from the workspace's
Cloudflare connection; nothing provider-shaped is stored in the repository
or in GitHub.

**Deploy by hand.** Orunbase's **Deploy** button on a component, or **Run
workflow** on the CI workflow in GitHub's Actions tab (on `main`), runs
`ci.yml` for the environment and components you pick, and each one deploys
exactly as a merge would deploy it. Leave the component blank to redeploy
every component in that environment, with nothing changed: after rotating a
secret, say. A component with nothing to run in that environment (a test
suite in `prod`) is left out with a notice.

## Custom domain

The blog answers on workers.dev from its first deploy. To serve it on your
own domain, add the domain to the Cloudflare account the blog deploys into
and attach it to the Worker (dashboard → Workers & Pages →
`cms-sanity-web-prod` → Settings → Domains & Routes → Add → Custom domain),
then add it to the Sanity project's CORS origins. The blog renders no
absolute link to itself (its share-image base URL is the Settings
document's Open Graph `metadataBase`, set in the Studio), so nothing else
has to change; the repository names the domain in one place, `BASE_DOMAIN`
in `intent.yaml` (dev, stage and prod), which the blog was born with as the
reserved placeholder `cms-sanity.example.com`. Replace it with your domain
in the same change that records it.
