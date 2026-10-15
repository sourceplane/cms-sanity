# cms-sanity — implementation plan

Milestones land in order; each task is one pull request on an
`orun/CS-n-<slug>` branch with an `Orun-Task: CS-n` trailer.

## CS0 — the spec ✅

This doc set, `epic.yaml` and the task contracts, merged to `main`.

**Done when**
- the five documents and `epic.yaml` are on `main`
- `tasks/CS-1..CS-3.TaskContract.yaml` exist

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

## Sequencing note

CS1 needs only CS0's contracts; CS2 is documentation over CS1's verified
build. Deploying is the gated Orun lane, not a milestone; rendering a real
post needs a Sanity project, which is the product's.
