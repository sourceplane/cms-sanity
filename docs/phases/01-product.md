# 01-product — the blog, built in one landing

**Places** everything a blog built from this baseline is made of, as ONE
pull request: the root manifests (`intent.yaml`, `package.json`, the pnpm
workspace and lockfile, `turbo.json`, the kiox pin), `.github/workflows`
(`ci.yml` and `checks.yml` — the baseline's own `baseline.yml` and
`tag.yml` are ignored), the shared TypeScript/ESLint config and the wrangler
renderer, the blog's README and its two context pages, the identity file
`.rebrand/values.json`, `.gitkeep` files for the four discovery roots, and
`apps/web` (the Next.js app, its Studio and its deploy contract) with
`tests/web` (vitest).

**Requires** the GitHub App installation on `githuborg` and the Cloudflare
connection — both probed, each waited for up to ten minutes. The platform
sees a pull request only through the installation on the account that owns
the repository, and every deploy credential is minted from the Cloudflare
connection. It does **not** require Sanity: the blog it lands builds,
deploys and serves with no Sanity project behind it.

## What runs

| hook | what it does |
|---|---|
| `task` (pre) | finds the phase's task (opened by the run-level list) and yields its key |
| `retouch` | the redeploy marker on `apps/web/component.yaml` and `tests/web/component.yaml` (`.baseline/tasks/01-product.TaskContract.yaml`'s `affects`) |
| `git-init`, `git-stage` | the rebrand enumerates with `git ls-files`, so the tree is a staged repo first |
| `rebrand` | renames the baseline's identity to the blog's (`tooling/rebrand/rebrand.mjs`): the repo slug, the Worker name, the secret project, the `SITE_NAME` seam, the domain, the subdomain — and leaves the upstream template's `examples/cms-sanity` links alone |
| `orun-workspace` | writes the blog's workspace into `intent.yaml` (`ws_SET_ME` if there is none — loud, not silent) |
| `work-tree` | removes the baseline's own `work:` block from `intent.yaml` — `specs/` and `tasks/` do not ship |
| `promotion` | defers prod's wait on stage until `02-docs` (both environments deploy side by side) |
| `dev-lanes` | keeps dev's verify lanes off main's convergences until `02-docs` |
| `git-restage`, `rebrand-verify` | refuses the landing if any baseline identity is left |
| `pnpm-lockfile` | confirms the placed lockfile (`--lockfile-only`) |
| `repo` | `orun.repo/ensure@v1` — creates `githuborg/reponame` (private unless `repoPrivate=false`) |
| `link` | `orun cloud link` (best effort) then `orun cloud check` — an unlinked repo stops here |
| `secret-workers-deploy` | `orun.integrations/reconcile@v1` — ensures `CLOUDFLARE_API_TOKEN`, brokered from the Cloudflare connection with the `workers-deploy` scope |
| `secret-account-id` | ensures `CLOUDFLARE_ACCOUNT_ID`, the connection fact |
| `land` | one PR, waited for (Checks + `plan`) and merged |
| `converge` (await) | `orun.run/watch@v1` on the merge commit's run; resumes it up to three times |
| `verify` (await) | `orun.http/probe@v1` on both workers.dev URLs |

There is no `orun.secrets/exists@v1` await: the blog has no infra component,
so nothing lease-publishes a `WIRING_*` secret. Nothing is minted for
Sanity: the project id and dataset are optional secret references the build
skips while nobody has stored them, and the read token is a Worker secret
the owner adds.

## What the convergence does

`orun plan --changed` plans `web` on stage and prod (the `deploy` profile)
and — dev's push activation being deferred — nothing on dev (`web-tests`
verifies on dev only). Each lane:

1. installs the workspace (`pnpm install --frozen-lockfile`) inside the
   job's own tree (stack-tectonic 0.19.0: Turbopack refuses a
   `node_modules` linked from outside it);
2. `verify-app-structure` — `test -f package.json` and
   `test -f wrangler.jsonc`, BEFORE any build: the config is committed, never
   generated;
3. `build-app` — Sanity TypeGen, `next build` on Turbopack, the OpenNext
   bundle. The environment's `SANITY_PROJECT_ID` and `SANITY_DATASET`
   secrets are resolved best-effort: on a fresh product neither exists, and
   the build is the unconnected blog (sample posts, a notice, a connect
   page at `/studio`);
4. `verify-build-output` — the Worker entrypoint and the assets directory;
5. deploys `<reponame>-web-<env>` with `wrangler deploy` (retried on
   Cloudflare's first-deploy race);
6. smoke-tests it: `/` must render the blog's layout and
   `/api/draft-mode/enable` must answer 401 to a request without a preview
   secret — the Worker's own code (retried while the route propagates).

Stage and prod deploy side by side (the promotion gate is deferred).

## Verified

The convergence run for the merge commit is green, and
`https://<reponame>-web-{stage,prod}.<subdomain>.workers.dev` answer.

## Troubleshooting

| symptom | cause → fix |
|---|---|
| parks on `waiting for github for <org>` | the workspace's GitHub connection is to another account. Connect the App installation on `<org>` (console → Integrations → GitHub), then `--resume` |
| parks on the `providers` probe for cloudflare | Cloudflare is not connected to the workspace. Connect it (console → Integrations → Cloudflare, paste the Account API token) |
| `link` fails: `… is not linked to workspace` | the credential cannot write links and the platform has not linked the repo. Allow-list it (console → Settings → Git repos) and re-run the phase |
| `rebrand-verify` lists leftovers | a file carries an identity form no rule renames. Add a rule to `tooling/rebrand/rebrand.mjs` (and a case to `testing/rebrand.test.sh`) |
| `intent.yaml` says `workspace: ws_SET_ME` | `orunWorkspace` was empty and the build ran outside a workspace. Set it and re-run |
| deploy lane: `secret resolution failed … CLOUDFLARE_API_TOKEN` | the reconcile did not run or minted against a revoked connection. Re-connect and re-run the phase; the reconcile re-mints only what is missing |
| deploy lane: Authentication error (10000) | the connection's token lacks Workers Scripts Write. Re-issue it with the permission groups the console's Connect recipe lists |
| build: `Symlink … points out of the filesystem root` | the composition installs once per lane and links it in (stack-tectonic ≥ 0.20.0). The product pins 0.19.0 for this; keep the pin |
| smoke fails right after the FIRST deploy | workers.dev route propagation; the composition retries the smoke with backoff (~4.5 min). A convergence resume clears what is left |
| the blog shows "Sample content" | expected: no Sanity project is connected yet. The blog's README, "Connecting Sanity" |
| the watch says green, the probe says 404 | another workflow ran on the push and the watch took its run. Only `ci.yml` may run on a push to main |
| re-run lands nothing | the hooks did not run (`--run-hooks`), or the contract names no component — `node tooling/bootstrap/retouch.mjs --check --affects .baseline/tasks/01-product.TaskContract.yaml` in the blog's tree says which |

## Re-running

Idempotent: placement is additive, rebrand is a no-op on branded files,
`git init` and the repo step are guarded, and the reconcile keeps keys that
exist. A re-run of a phase whose PR already merged lands the retouch markers
alone, which re-plans exactly the components it names. Once the tree is
branded the phase derives as `drifted`, so `--resume` leaves it alone; re-run
it deliberately with `--phase 01-product` (or `--redo 01-product` under
`--resume`).
