# cms-sanity — operating contract (for humans and agents)

This is the standing guide to how this blog is deployed and operated.
Instance facts (live URLs, workspace, secrets inventory) live in
[deployment.md](deployment.md), rendered from probed reality by the
bootstrap's `02-docs` phase; this file is the contract that stays true
between deployments. It is written to give an agent with repository read
access enough context to reason about and operate the blog without any
other source.

## What this system is

A blog whose content lives in [Sanity](https://www.sanity.io), served from
Cloudflare, expressed as an Orun component-native desired-state repo.

- **`apps/web`** — Next.js built by `@opennextjs/cloudflare` into one Worker
  plus Static Assets. `/` and `/posts/<slug>` render per request against
  Sanity's API CDN (60 s cache); the Sanity Studio is mounted at `/studio`
  and ships as static assets; `/api/draft-mode/enable` turns on draft mode
  for the Studio's live preview.
- **`tests/web`** — vitest over the Sanity helpers, the draft-mode route and
  the unconnected blog, verified on the `dev` rung.
- **`tooling/*`** — shared TypeScript and ESLint configuration, and the
  wrangler renderer for a deployable that comes to take wiring.

There is no infrastructure component: Sanity is a hosted service the blog
reads over HTTPS, not something this repository provisions.

Environments: **`stage`** and **`prod`** are deployed; **`dev` is
verify-only by design** — lanes build and test, nothing deploys.

## Sanity: connected, or sample posts

The blog reads ONE Sanity project and dataset, fixed at build time (`next
build` inlines them). Until a build has a project id it is **unconnected**:
every page renders the sample posts bundled in `apps/web/sanity/lib/sample.ts`
under a "connect your Sanity project" notice, `/studio` shows how to connect
instead of a Studio, and draft mode answers 401 with the reason. Nothing
fails: an unconnected blog deploys, passes its smoke test and serves.

To connect it, per deployed environment:

```bash
# 1. the project and dataset (public values; the next build reads them)
orun secrets set SANITY_PROJECT_ID --env stage    # prompts for the value
orun secrets set SANITY_DATASET    --env stage    # usually "production"; unset means production
# …and the same with --env prod

# 2. redeploy apps/web: the values are read when it BUILDS, and setting a
#    secret builds nothing. Change the stamp on the last line of
#    apps/web/component.yaml (`# orun: redeploy <reason> <stamp>`) and merge.

# 3. draft mode / live preview: a Viewer token, as a Worker secret
#    (Cloudflare's, not Orun's — the deploy never touches it, so it survives deploys)
pnpm --filter @app/web exec wrangler secret put SANITY_API_READ_TOKEN --name cms-sanity-web-stage
```

And once per project, in Sanity's management console (API → CORS origins):
add each Worker URL (`https://cms-sanity-web-<env>.your-workers-subdomain.workers.dev`,
and any custom domain) **with credentials allowed**, or the Studio cannot
sign in from the site.

The secrets are read best-effort (`optionalSecretEnv` in
`apps/web/component.yaml`): a key nobody has stored is skipped, never a
failed lane. A wrong project id or dataset is not caught at build: the
blog's pages then fail at request time with Sanity's error, so probe `/`
after connecting.

## Identity and tenancy

Every remote operation runs against ONE Orun workspace, declared in
`intent.yaml` under `execution.state.workspace` — committed, enforced, and
what CI uses. Do not remove it; headless credentials depend on it. If it
reads `ws_SET_ME`, the bootstrap had no workspace to write: set the real one
before anything else.

## How deployment works

1. Merge (or push) to `main`.
2. CI (`.github/workflows/ci.yml`) runs `orun plan --changed` — only
   components whose files changed are planned — then runs each planned lane
   with `orun run --remote-state`, authenticated by GitHub OIDC (the
   exchange resolves this repository's linked workspace server-side).
3. `apps/web` checks its committed `wrangler.jsonc` is there, builds once per
   environment with that environment's Sanity project (if any), `wrangler
   deploy` ships `cms-sanity-web-<env>`, and a smoke test fetches `/` and
   requires the blog's layout, then requires `/api/draft-mode/enable` to
   refuse a request without a preview secret (401) — proof the Worker's
   server code answers.
4. `prod` deploys after `stage` has converged on the same commit
   (`environments.prod.promotion` in intent.yaml).
5. **The convergence run is the deployment.** A green run means every
   planned lane passed. Failed lanes are retried with
   `gh run rerun --failed`, which resumes the same execution.

On a pull request nothing deploys: the blog builds and dry-deploys.

Caveats that matter:

- A push that touches no component files plans zero lanes — that run is
  green and deployed nothing. Never treat "latest run green" as "blog
  converged"; probe the URLs instead.
- Published content needs no deploy: the blog reads Sanity on every request,
  so a published post shows within the API CDN's 60 s.
- A change to `intent.yaml`'s `environments`, or to an Orun secret, maps to
  no component and redeploys nothing on its own. Land it with a change under
  `apps/web`.

## Secrets model

- **Brokered provider secrets**: `CLOUDFLARE_API_TOKEN` (the
  `workers-deploy` scope) and `CLOUDFLARE_ACCOUNT_ID` — pointers minted per
  run from the workspace's Cloudflare connection. No long-lived values at
  rest; nothing to rotate by hand.
- **The Sanity project**: `SANITY_PROJECT_ID` and `SANITY_DATASET` on
  `stage` and `prod`, stored by the owner, read by the build. Public values,
  kept as secrets so each environment can name its own.
- **The read token**: `SANITY_API_READ_TOKEN`, a Worker secret per
  environment, read at request time by draft mode only.
- Inspect by NAME only: `orun secrets list --org <ws> --env stage|prod`. No
  tooling in this repository prints a secret value, and no document in
  `ai/context/` may contain one.

## Verifying the system

```bash
# the blog on each environment (also recorded, probed, in deployment.md);
# an unconnected blog carries data-sanity-notice="unconnected"
curl -s https://cms-sanity-web-stage.your-workers-subdomain.workers.dev/ | grep -o 'data-sanity-notice="[a-z]*"'
curl -s -o /dev/null -w '%{http_code}\n' https://cms-sanity-web-prod.your-workers-subdomain.workers.dev/studio
curl -s -o /dev/null -w '%{http_code}\n' https://cms-sanity-web-prod.your-workers-subdomain.workers.dev/api/draft-mode/enable   # 401

# workspace readiness
orun secrets list --org <ws> --env stage && orun secrets list --org <ws> --env prod
orun integrations list --org <ws> --json && orun cloud check --org <ws>
```

## Common operations

| task | how |
|---|---|
| connect a Sanity project | "Sanity: connected, or sample posts" above |
| write, edit, publish | `/studio` on the deployed site (or `pnpm --filter @app/web dev` → `localhost:3000/studio`); no deploy needed |
| change the blog's code | edit `apps/web` (its fallback name: `apps/web/app/site.ts`), merge |
| change the content model | the schemas in `apps/web/sanity/schemas`, then `pnpm --filter @app/web typegen` and commit `schema.json` and `sanity.types.ts` with them |
| deploy a change | merge to `main`; watch the run; failed lanes → `gh run rerun --failed` |
| redeploy without a change | edit the last line of `apps/web/component.yaml` (`# orun: redeploy <reason> <stamp>`) and merge — it is a deploy trigger, nothing reads it |
| serve a custom domain | attach it to the Worker in Cloudflare (README, "Custom domain"), add it to the Sanity project's CORS origins, then replace the placeholder `cms-sanity.example.com` in `intent.yaml`'s `BASE_DOMAIN` (dev, stage and prod) with it |
| headless credentials | `ORUN_TOKEN` (workspace-scoped) + `GITHUB_TOKEN` |

The deployment record is the bootstrap's `02-docs` phase. Re-running it (the
Orun console's Retry on that phase, or `orun new … --phase 02-docs`)
re-probes the URLs and re-renders [deployment.md](deployment.md); it is
idempotent.

## Evolution

Structural changes follow the same contract that deployed the blog: add a
component under `apps/`, `infra/` or `packages/` with a `component.yaml`,
land it as a pull request, and the convergence run deploys it. A component
under `infra/` whose wiring the Worker reads is declared in `apps/web`'s
`dependsOn` (enforced on `main`), so it is applied first.
