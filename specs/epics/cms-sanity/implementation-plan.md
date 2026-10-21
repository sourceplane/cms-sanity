# cms-sanity — implementation plan

Milestones land in order; each task is one pull request on an
`orun/CS-n-<slug>` branch with an `Orun-Task: CS-n` trailer.

## CS0 — the spec ✅

This doc set, `epic.yaml` and the task contracts, merged to `main`.

**Done when**
- the five documents and `epic.yaml` are on `main`
- `tasks/CS-1..CS-3.TaskContract.yaml` exist (CS-4 joined with CS3)

## CS1 — the blog on Workers ✅

`apps/web` is the upstream template with the Workers build around it;
`tests/web` exercises the image URL builder, the date component and the
draft-mode enable route.

**Done when**
- `pnpm install && pnpm typecheck && pnpm lint && pnpm test && pnpm build` is green locally and in `Checks`, with no Sanity project, dataset or token set
- the Worker bundle holds no Studio code (`wrangler deploy --dry-run` well under the 3 MB gzip free-plan limit) and the Studio is in `_next/static`
- `wrangler dev` answers `/studio` (200, the Studio shell with `robots: noindex`), `/studio/structure` (200), a `_next/static` chunk (200), `/favicon.ico` (200), `/nope` (404) and `/api/draft-mode/enable` without a secret (401 `Invalid secret`, no network); `/` and `/posts/[slug]` reach Sanity's API CDN for the configured project

## CS2 — ready to instantiate ✅

README (run, test, preview, deploy; the Sanity project, dataset and read
token; `NEXT_PUBLIC_CF_BEACON_TOKEN`), `IMPLEMENTATION-STATUS.md`, epic
`completed`.

**Done when**
- the README quick start works from a fresh clone
- the status file lists every PR and departure

## CS3 — a baseline (CS-4) ✅

`blueprint.yaml`, `repo-blueprint.yaml`, `.baseline/` (identity, task
contracts, the blog's README), `tooling/rebrand`, `tooling/bootstrap`,
`hooks/render-deployment-docs.sh`, `ai/context/`, `docs/phases/`,
`BOOTSTRAP.md`, `testing/`, `baseline.yml` and `tag.yml`; in the blog, the
`SITE_NAME` seam, the unconnected blog (sample posts, the notice, the
Studio's connect page, draft mode's 401) and best-effort Sanity secret refs
(design §6).

**Done when**
- orun at the bootstrap floor (v2.58.11), at the lane pin (v2.78.4) and the
  current CLI (2.79.0) reads `repo-blueprint.yaml`, and
  `testing/manifest.test.sh` holds the card to it
- a build with no Sanity project serves `/`, every sample post, `/studio`
  and a 404 — and draft mode's 401 — under `wrangler dev`
- `Baseline CI` is green: the contract tests, the leak gate, the offline
  bootstrap (`testing/placement.test.sh`) and the end-to-end tier
  (`testing/e2e.test.sh`), the latter with no Sanity credentials
- the status file records what is proven offline and what only a live
  bootstrap (and a real Sanity project) can prove

## CS4 — the cirrus standard (CS-5) ✅

Bring the baseline to cirrus-baseline's standard, with nothing about the
blog itself changing.

- **No kiox.** `kiox.yaml`/`kiox.lock` pinned an orun (v2.15.0) that nothing
  ran: every workflow installs orun itself through `orun-action` with its own
  `version:`. The files, their two modules and the rebrand's skip entry go.
- **Component docs.** `tooling/catalog/gen-component-docs.py` writes each
  component's `docs/overview.md`, `docs/architecture.md` and `docs/runbook.md`
  from what the component declares, as cirrus-baseline's do; the pages ship
  with the component. Baseline CI runs it with `--check`.
- **The context pack.** `ai/context/current.md`, `decisions.md` and
  `open-risks.md` beside the two pages a blog ships with — this
  repository's own, so no module places them.
- **Status that agrees with the tags.** CS3 is shipped and tagged
  `baseline-v1`; the READMEs no longer call the Presentation preview simply
  "unchanged" while CS-H is open.
- **The subdomain from the Cloudflare connection (CS-6).** The card's
  `subdomain` input declares `from: connection.cloudflare.workersSubdomain`,
  as cirrus-baseline's does since baseline-v23: the bootstrap door fills it
  from the connection the build is bound to, so the console asks for nothing
  a typo could get wrong. `testing/manifest.test.sh` takes cirrus-baseline's
  rule, which requires the provider in `spec.requires.integrations`.

**Done when**
- nothing outside this milestone's own record names kiox (`git grep -i
  kiox`), and the leak gate and the offline bootstrap pass without the two
  modules
- the docs check is green in Baseline CI
- this file, the status file and `epic.yaml` agree

## After CS3 (outside this repository)

1. Cut `baseline-v1` with `tag.yml` from the merged `main` — done: `baseline-v1`
   is [#4](https://github.com/sourceplane/cms-sanity/pull/4)'s merge.
2. Register the row in orun-cloud's `infra/baselines-registry/baselines.yaml`
   (unlisted) with the card vendored at the tag.
3. Bootstrap one blog from the tag against a workspace; record its timings;
   connect a Sanity project to it and see the samples give way; then flip
   the row to public with a page on orunbase.com.

## Sequencing note

CS1 needs only CS0's contracts; CS2 is documentation over CS1's verified
build; CS3 packages CS1's blog as a baseline. Deploying is the Orun lane,
which runs once `intent.yaml` names a workspace — a bootstrap writes the
product's. Rendering a real post needs a Sanity project, which is the
product owner's to connect after the bootstrap.
