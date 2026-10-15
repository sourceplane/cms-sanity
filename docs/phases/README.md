# The phases — one blueprint, two selections

`repo-blueprint.yaml` declares two phases that take a blog from **nothing**
to **live on stage and prod, documented**. Run them one at a time with
`--phase <name>`, or the whole sequence unattended with `--resume`. There is
no umbrella workflow and no per-phase document: a phase is a selection on one
artifact, which is what makes running one alone, months later, from a fresh
container the same operation as running them all.

Each phase follows the same contract:

> **place its modules → brand them → land them as one pull request → watch
> the convergence that merge triggers (auto-resumed) → verify the outcome
> over HTTP.**

Run from the baseline checkout (the blueprint's source is `path: .`); the
blog's repository is wherever `--out` points.

## One landing builds the product

Since cirrus-baseline's baseline-v22 the whole product lands as ONE pull
request and ONE convergence on main deploys it. Before that a bootstrap paid
a landing's fixed cost per layer — place, open a PR, wait for its checks,
merge, wait for the convergence to start — for order the plan can carry by
itself. This baseline is built that way from the start: `01-product` places
every module, and `02-docs` records what went live.

| what has to come first | how the plan holds it |
|---|---|
| infrastructure before anything that reads its wiring | a component reading an infra component's `WIRING_*` declares `dependsOn` on it, `mode: enforced` on `github-push-main` (advisory on pull requests). **This blog has no infra** — Sanity is a hosted service it reads, not infrastructure it applies — so nothing waits: `web` deploys to stage and prod side by side |
| stage before prod | deferred for the bootstrap (`promotion.mjs --defer`), restored by `02-docs` |
| dev's verify lanes on main | deferred for the bootstrap (`dev-lanes.mjs --defer`), restored by `02-docs`; pull requests keep them throughout |

## Execution order

The phase number is the EXECUTION order, and each phase's `requires.phases`
states it in the document: the engine refuses a phase whose predecessor is not
placed, and names it.

Every landing is a pull request on a branch named for its task
(`orun/BASE-<n>-<phase>`). On those branches `ci.yml` runs `plan` only — the
intent, every component and every composition resolve — and skips the lanes,
because the merge runs them on main a minute later, for real, and that
convergence is what the phase watches. `checks.yml` (install, typecheck, lint,
test, build) runs on every pull request regardless, and the landing waits for
it.

| phase | lands | verified by |
|---|---|---|
| [`01-product`](01-product.md) | **the GitHub repo created**, then the WHOLE blog in one PR: intent, CI, tooling, identity, `apps/web` + `tests/web` — one convergence deploys it to stage and prod | convergence green (build, deploy, smoke) + the blog answers on both URLs |
| [`02-docs`](02-docs.md) | the live-deployment record; the promotion gate and dev lanes put back | committed manifest matches probed reality |

There is no custom-domain phase. Attaching a domain to a Worker needs zone
permissions the platform's brokered `workers-deploy` token does not carry, so
it is an owner's step after the bootstrap — the blog's README, "Custom
domain", says how.

There is no Sanity phase either. Sanity is not a provider the platform
brokers, so no phase can create a project or mint a token: the blog is
built, deployed and verified WITHOUT one — it serves bundled sample posts
under a "connect your Sanity project" notice — and its owner connects a
project afterwards (the blog's README, "Connecting Sanity": two optional
secrets, a redeploy, the CORS origins and a Worker secret for draft mode).

## Inputs

`01-product` takes the blog's identity once and writes it into the repo
(`.rebrand/values.json`); `02-docs` reads it back from the placed tree. But
the blueprint's **required** inputs — `reponame`, `productname`,
`productdomain`, `githuborg` — are validated before any phase runs, so they
must be supplied on every invocation, single-phase ones included. A
`--values` file is easier than repeating `--set`.

- `subdomain` — the workers.dev subdomain of the Cloudflare account. It is
  in every URL the phases probe and in the URL the deploy's smoke reads.
- `orunWorkspace` — workspace id (`ws_…`). Unset, it is the workspace the
  build runs in (`from: workspace`); with none anywhere, a placeholder that
  fails loudly rather than silently claiming another tenant's workspace.
- `epicSlug` (default `cms-sanity-baselining`) — the epic every phase clubs
  its task under. Found by slug, so a fresh run and a resumed run find the
  same work.
- `repoPrivate` (default `true`) — the repository's visibility at creation.

```bash
orun new --blueprint repo-blueprint.yaml \
  --out $HOME/blogs/acme-notes --run-hooks --phase 01-product \
  --values ~/acme-notes.values.yaml
```

Drop `--run-hooks` (or add `--status`) to preview. Without it a phase places
files and stops: no repo, no landing, no convergence watch, and no probe —
which is exactly what makes a dry instantiation of this baseline possible in
CI with no workspace and no provider (`testing/placement.test.sh`,
`testing/e2e.test.sh`).

## What 01-product does after it places

Placement writes the baseline's files as they are here. Before the phase
lands, its `post` hooks make them the blog's:

1. `retouch` — one `# orun: redeploy 01-product <stamp>` line at the end of
   each component.yaml its task contract names, so a re-run after a failed
   convergence still has a diff to land and redeploys exactly those
   components.
2. `git init`, `git add` — the rebrand enumerates with `git ls-files`.
3. `rebrand` → the intent's `workspace:` → `work-tree --strip` → the two
   deferrals → `git add` → `rebrand --verify` — the identity rename over the
   whole tree, the re-tenant, and a sweep that fails on any of this
   baseline's identity left behind.
4. `pnpm install --lockfile-only` — the baseline's complete lockfile is
   already placed, so this confirms it.
5. `repo`, `link`, the two brokered credentials, `land`.

## When a phase fails

- **Before it lands** (a probe that timed out, a rebrand residue, a refused
  link): nothing was merged. Fix what the message names and re-run the phase.
- **After it lands** (the convergence went red): the files are on main.
  `orun.run/watch@v1` has already resumed the run up to three times. Re-run
  the phase (`--phase 01-product`, `--redo 01-product` under `--resume`, or
  the console's Retry): its `retouch` hook gives the landing a diff and the
  blog redeploys.
