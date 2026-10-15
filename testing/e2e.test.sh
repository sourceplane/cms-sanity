#!/usr/bin/env bash
# TIER 2 — the blog a bootstrap produces builds, deploys (dry) and serves,
# with NO Sanity project behind it.
#
# placement.test.sh proves the tree a bootstrap ends with is the right tree.
# This proves it WORKS, by doing to it what its own pipelines will — on the
# day it is built, when its owner has not connected a Sanity project yet:
#
#   1. at the 01-product landing (the commit its one pull request merges), run
#      what `checks.yml` runs on that PR — install with the placed lockfile,
#      render fixtures and check the committed config is the render,
#      typecheck, lint, test, build. That landing WAITS on its checks, so a
#      product they refuse is a bootstrap that never lands; then the same at
#      the 02-docs landing, which waits on them too;
#   2. the stage lane's own steps, read out of `orun plan` in the product for
#      a pull request (the verify profile: the deploy profile has no dry run)
#      — EVERY `run:` step of the job, in order, exactly as planned: the
#      install, `verify-app-structure` (the committed `package.json` and
#      `wrangler.jsonc`, checked BEFORE any build), `build-app` (TypeGen,
#      `next build` on Turbopack, the OpenNext bundle), `verify-build-output`
#      and `deploy-dry-run` (`wrangler deploy --dry-run --name
#      <reponame>-web-stage`). They run IN THE TREE THE RUNNER STAGES for the
#      job (testing/lib/stage-job.py), with no build output in it and the
#      dependency layout the pinned composition produces: if its install step
#      is `scope: lane`, the top-level node_modules is a symlink to the source
#      checkout's (which Turbopack refuses); if not, the job's own install
#      step runs inside the staged tree. The job's Sanity refs are optional,
#      and a fresh product has stored none, so the lane runs with no
#      NEXT_PUBLIC_SANITY_* and no read token — as here;
#   3. serve the built Worker with `wrangler dev` and run the component's OWN
#      `smokeCommand` against it, verbatim and then inside the deploy
#      profile's planned `smoke` step (its retry loop and all — only its
#      workers.dev URL swapped for the local one) — the check the real deploy
#      ends with; then read every route the blog promises: the home page and
#      the three sample posts under the "connect your Sanity project" notice,
#      carrying the blog's name, a 404 for an unknown post and path, /studio
#      as the connect page, the static assets — and the route only the
#      Worker's server code answers: draft mode, refused with 401 and the
#      reason.
#
# What it cannot do is the platform's half: create the repository, mint the
# brokered Cloudflare token, deploy for real and probe workers.dev — nor
# Sanity's: a connected blog reading a real dataset needs a project. That is
# a bootstrap against a workspace (BOOTSTRAP.md); everything short of it is
# here.
#
# Needs: orun, node, pnpm, python3 (+PyYAML), git, curl, setsid, and the
# network for `pnpm install` and the build's Google Font (or a warm store).
# Several minutes: three installs and three Next.js builds.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
# shellcheck source=lib/bootstrap.sh
source "$here/lib/bootstrap.sh"

for bin in orun node pnpm python3 git curl setsid; do
  command -v "$bin" >/dev/null || { echo "e2e.test.sh needs $bin on PATH" >&2; exit 1; }
done

scratch="$(mktemp -d)"
dev_pid=""
# wrangler dev runs under pnpm, node and two workerd processes; a TERM to the
# first does not reach the rest, and waiting on it then never returns. So it is
# started as its own process group (setsid) and the whole group is stopped.
cleanup() {
  if [ -n "$dev_pid" ]; then
    kill -TERM -- "-$dev_pid" 2>/dev/null || true
    for _ in 1 2 3 4 5 6 7 8 9 10; do kill -0 -- "-$dev_pid" 2>/dev/null || break; sleep 0.5; done
    kill -KILL -- "-$dev_pid" 2>/dev/null || true
  fi
  rm -rf "$scratch"
}
trap cleanup EXIT
values="$here/fixtures/acme.json"
repo="$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['reponame'])" "$values")"
sub="$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['subdomain'])" "$values")"
export CI=1 WRANGLER_SEND_METRICS=false NEXT_TELEMETRY_DISABLED=1 TURBO_TELEMETRY_DISABLED=1
# NO SANITY CREDENTIALS, whatever the caller's shell holds: this is the blog
# its owner gets before connecting a project.
unset NEXT_PUBLIC_SANITY_PROJECT_ID NEXT_PUBLIC_SANITY_DATASET SANITY_API_READ_TOKEN SANITY_AUTH_TOKEN
free_port() { python3 -c "import socket;s=socket.socket();s.bind(('127.0.0.1',0));print(s.getsockname()[1]);s.close()"; }

# What checks.yml runs, step for step, read out of the workflow the product
# carries so the two cannot drift: every `run:` of its one job, in order.
checks() { # DIR LOG
  local dir="$1" log="$2" cmd
  while IFS= read -r cmd; do
    echo "   \$ $cmd" | tee -a "$log"
    if ! (cd "$dir" && bash -c "$cmd") >> "$log" 2>&1; then
      echo "FAIL: \`$cmd\` failed in $dir" >&2; tail -40 "$log" >&2; return 1
    fi
  done < <(python3 - "$dir/.github/workflows/checks.yml" <<'PY'
import sys, yaml
wf = yaml.safe_load(open(sys.argv[1]))
for job in wf["jobs"].values():
    for step in job["steps"]:
        if "run" in step:
            print(step["run"].strip())
PY
)
}

echo "── the offline bootstrap (testing/lib/bootstrap.sh)"
tree="$scratch/$repo"
bootstrap_offline "$root" "$tree" "$values" "$scratch/logs" > "$scratch/bootstrap.log" 2>&1 || {
  echo "FAIL: the offline bootstrap stopped" >&2; tail -40 "$scratch/bootstrap.log" >&2; exit 1; }
s00="$(git -C "$tree" rev-parse HEAD~2)"; s01="$(git -C "$tree" rev-parse HEAD~1)"
echo "   2 phases placed and landed on orun's Initial commit"

# ── 1. the checks each landing waits on ────────────────────────────────────
echo "── 01-product's landing, under the checks its PR waits on"
git -C "$tree" worktree add -q "$scratch/at-01" "$s01"
checks "$scratch/at-01" "$scratch/checks-01.log"
# Its tree is not needed again, and the disk is shared.
git -C "$tree" worktree remove --force "$scratch/at-01"

echo "── 02-docs's landing (the finished blog), under the same checks"
checks "$tree" "$scratch/checks-blog.log"
grep -q '(Turbopack)' "$scratch/checks-blog.log" \
  || { echo "FAIL: the Checks build did not run on Turbopack" >&2; exit 1; }

# ── 2. the stage lane, as a pull request plans it ──────────────────────────
echo "── the stage lane: every run step the PR plan gives web@stage, in a staged job tree"
(cd "$tree" && orun plan --intent intent.yaml --trigger github-pull-request --changed \
   --base "$s00" --head "$s01" --env stage --output "$scratch/plan-pr.json") > "$scratch/plan-pr.log" 2>&1 \
  || { echo "FAIL: orun plan (pull request)" >&2; tail -15 "$scratch/plan-pr.log" >&2; exit 1; }
python3 - "$scratch/plan-pr.json" "$scratch/steps" "$tree" "$values" <<'PY'
import json, pathlib, sys
import yaml
plan = json.load(open(sys.argv[1]))
out = pathlib.Path(sys.argv[2]); out.mkdir()
tree, values = pathlib.Path(sys.argv[3]), json.load(open(sys.argv[4]))
repo, ws = values["reponame"], values["orunWorkspace"]
job = next(j for j in plan["jobs"] if j["component"] == "web" and j["environment"] == "stage")
params = yaml.safe_load((tree / "apps/web/component.yaml").read_text())["spec"]["parameters"]
order, uses = [], []
for s in job["steps"]:
    if "use" in s:
        uses.append(f"{s['id']}\t{s['use']}\t{json.dumps(s.get('with') or {})}")
        continue
    order.append(s["id"])
    (out / f"{s['id']}.sh").write_text(s.get("run") or "")
    (out / f"{s['id']}.wd").write_text(s.get("working-directory") or ".")
    if s.get("scope"):
        (out / f"{s['id']}.scope").write_text(s["scope"])
(out / "order").write_text("\n".join(order) + "\n")
(out / "uses").write_text("\n".join(uses) + "\n")
(out / "path").write_text(job.get("path") or "apps/web")
(out / "profile").write_text(job["profile"])
(out / "node").write_text(params["nodeVersion"])
(out / "pnpm").write_text(params["pnpmVersion"])
for k, v in (job.get("env") or {}).items():
    (out / "env").open("a").write(f"export {k}={json.dumps(v)}\n")
# What the platform resolves into the job before its first step. The Sanity
# project's refs are OPTIONAL: on a product nobody has connected, nothing is
# stored under them, so nothing is exported — which is what this lane replays.
refs = {r["asEnv"]: r for r in job.get("secretRefs") or []}
for key in ("NEXT_PUBLIC_SANITY_PROJECT_ID", "NEXT_PUBLIC_SANITY_DATASET"):
    r = refs.get(key)
    if not r or r.get("optional") is not True or f"/{repo}/stage/" not in r.get("ref", ""):
        sys.exit(f"FAIL: the stage lane resolves {key} as {r} — want an optional ref to the product's stage secret")
required = sorted(k for k, r in refs.items() if not r.get("optional"))
if required:
    sys.exit(f"FAIL: the verify lane requires secrets {required}; a pull request's lane needs none")
PY
order="$(tr '\n' ' ' < "$scratch/steps/order")"
echo "   $(cat "$scratch/steps/profile"): $order"
for need in install-workspace-dependencies verify-app-structure build-app verify-build-output deploy-dry-run; do
  grep -qx "$need" "$scratch/steps/order" || { echo "FAIL: the stage lane plans no $need step" >&2; exit 1; }
done
[ "$(grep -n -x verify-app-structure "$scratch/steps/order" | cut -d: -f1)" -lt "$(grep -n -x build-app "$scratch/steps/order" | cut -d: -f1)" ] \
  || { echo "FAIL: the structure check is planned after the build" >&2; exit 1; }
# The `use:` steps set up the runner's toolchain; here it is this machine's,
# so it must be the one the component asks for.
node_major="$(node -p 'process.versions.node.split(".")[0]')"
[ "$node_major" = "$(cat "$scratch/steps/node")" ] || { echo "FAIL: node $node_major here, the lane sets up $(cat "$scratch/steps/node")" >&2; exit 1; }
[ "$(pnpm --version)" = "$(cat "$scratch/steps/pnpm")" ] || { echo "FAIL: pnpm $(pnpm --version) here, the lane sets up $(cat "$scratch/steps/pnpm")" >&2; exit 1; }
echo "   setup-node $node_major and setup-pnpm $(pnpm --version) stand in for the lane's \`use:\` steps"
echo "   the Sanity project's refs are optional and unstored: the lane builds with none"

# The job's private tree, staged as orun stages it, from a source checkout
# with no build output (a CI checkout has none, so step 1's is removed rather
# than copied in) and the dependencies the pinned composition says: a
# lane-scoped install ran once in the source tree (step 1 ran the same
# command) and is linked in, or the job installs its own.
rm -rf "$tree/apps/web/.next" "$tree/apps/web/.open-next" "$tree/apps/web/.wrangler" "$tree/tests/web/coverage"
work="$tree/.orun/runs/e2e/web.stage.verify-deploy/work"
install_scope="$(cat "$scratch/steps/install-workspace-dependencies.scope" 2>/dev/null || echo job)"
if [ "$install_scope" = lane ]; then
  python3 "$here/lib/stage-job.py" "$tree" "$work" --shared-deps
  [ -L "$work/node_modules" ] || { echo "FAIL: the staged tree's node_modules is not the lane's symlink" >&2; exit 1; }
else
  python3 "$here/lib/stage-job.py" "$tree" "$work"
  [ ! -e "$work/node_modules" ] || { echo "FAIL: the staged tree carries node_modules it should install" >&2; exit 1; }
fi
for built in apps/web/.next apps/web/.open-next apps/web/.wrangler; do
  [ ! -e "$work/$built" ] || { echo "FAIL: the staged tree carries build output ($built)" >&2; exit 1; }
done
echo "   staged: $(realpath --relative-to="$tree" "$work"); install scope: $install_scope; no build output"

while IFS= read -r step; do
  [ -n "$step" ] || continue
  if [ "$step" = install-workspace-dependencies ] && [ "$install_scope" = lane ]; then
    echo "   · $step (lane-scoped: ran once in the source tree)"; continue
  fi
  echo "   ▸ $step"
  # The runner's per-job environment: the job's env (intent environment
  # `env:`) and ORUN_ENVIRONMENT; the step runs in the component's directory.
  if ! (cd "$work/$(cat "$scratch/steps/path")/$(cat "$scratch/steps/$step.wd")" && \
        { [ -f "$scratch/steps/env" ] && source "$scratch/steps/env"; true; } && \
        export ORUN_ENVIRONMENT=stage && bash -e "$scratch/steps/$step.sh") > "$scratch/$step.log" 2>&1; then
    echo "FAIL: the stage lane's $step step" >&2; tail -40 "$scratch/$step.log" >&2; exit 1
  fi
done < "$scratch/steps/order"
[ "$install_scope" = lane ] || { [ -d "$work/node_modules" ] && [ ! -L "$work/node_modules" ]; } \
  || { echo "FAIL: the job's install did not land inside its own tree" >&2; exit 1; }
# The build this blog is verified with: Turbopack (a webpack build would get
# past an out-of-tree symlink and is not the build that deploys).
grep -q '(Turbopack)' "$scratch/build-app.log" \
  || { echo "FAIL: the staged build did not run on Turbopack" >&2; grep -m3 'Next.js' "$scratch/build-app.log" >&2; exit 1; }
grep -q -- "--name \"\${EFFECTIVE_WORKER_NAME}\"" "$scratch/steps/deploy-dry-run.sh" && grep -q "$repo-web-stage" "$scratch/steps/deploy-dry-run.sh" \
  || { echo "FAIL: the dry run does not name the Worker $repo-web-stage" >&2; exit 1; }
grep -q 'Total Upload' "$scratch/deploy-dry-run.log" \
  || { echo "FAIL: the dry run bundled nothing" >&2; tail -20 "$scratch/deploy-dry-run.log" >&2; exit 1; }
echo "   the staged build ran on Turbopack; the dry run bundled $repo-web-stage ($(grep -m1 -o 'Total Upload: .*' "$scratch/deploy-dry-run.log"))"

# ── 3. serve it, and smoke it as the deploy does ───────────────────────────
echo "── wrangler dev over the staged Worker, no Sanity project, no read token"
port="$(free_port)"; iport="$(free_port)"
# setsid without its own fork: the subshell is not a group leader, so the
# pid recorded IS the new process group's.
(cd "$work/apps/web" && exec setsid pnpm exec wrangler dev --config wrangler.jsonc --name "$repo-web-stage" \
   --ip 127.0.0.1 --port "$port" --inspector-port "$iport" --show-interactive-dev-session=false) \
   > "$scratch/dev.log" 2>&1 < /dev/null &
dev_pid=$!
url="http://127.0.0.1:$port"
for _ in $(seq 1 120); do
  curl -s -o /dev/null "$url/favicon.ico" && break
  kill -0 "$dev_pid" 2>/dev/null || { echo "FAIL: wrangler dev exited" >&2; tail -30 "$scratch/dev.log" >&2; exit 1; }
  sleep 1
done
curl -s -o /dev/null "$url/favicon.ico" || { echo "FAIL: wrangler dev never answered" >&2; tail -30 "$scratch/dev.log" >&2; exit 1; }

smoke="$(python3 -c "import yaml,sys;print(yaml.safe_load(open(sys.argv[1]))['spec']['parameters']['smokeCommand'])" "$tree/apps/web/component.yaml")"
echo "   ▸ the component's own smokeCommand, verbatim, DEPLOYED_URL=$url"
DEPLOYED_URL="$url" bash -c "$smoke" || { echo "FAIL: the deploy's smoke refused the blog" >&2; exit 1; }
if DEPLOYED_URL="$url/no-such-blog" bash -c "$smoke" 2>/dev/null; then
  echo "FAIL: the smoke passed against a path that is not the blog — it checks nothing" >&2; exit 1
fi
echo "   ▸ …and it refuses what is not the blog"

(cd "$tree" && orun plan --intent intent.yaml --trigger github-push-main --changed \
   --base "$s00" --head "$s01" --env stage --output "$scratch/plan-push.json") > "$scratch/plan-push.log" 2>&1 \
  || { echo "FAIL: orun plan (push to main)" >&2; tail -15 "$scratch/plan-push.log" >&2; exit 1; }
python3 - "$scratch/plan-push.json" "$scratch/smoke-step.sh" "https://$repo-web-stage.$sub.workers.dev" <<'PY'
import json, sys
plan, out, origin = json.load(open(sys.argv[1])), sys.argv[2], sys.argv[3]
job = next(j for j in plan["jobs"] if j["component"] == "web" and j["environment"] == "stage")
assert job["profile"].endswith(".deploy"), job["profile"]
run = next(s for s in job["steps"] if s["id"] == "smoke")["run"]
# The one thing offline cannot reach is workers.dev: the step derives its URL
# from the Worker's name and the account's subdomain, so that line — and only
# that line — is pointed at the local Worker, after checking it is this blog's.
line = 'export DEPLOYED_URL="https://${EFFECTIVE_WORKER_NAME}.${WORKERS_DEV_SUBDOMAIN}.workers.dev"'
if line not in run or 'EFFECTIVE_WORKER_NAME="' + origin.split("//")[1].split(".")[0] + '"' not in run:
    sys.exit(f"FAIL: the planned smoke step does not derive {origin}:\n{run}")
open(out, "w").write(run.replace(line, 'export DEPLOYED_URL="${E2E_LOCAL_URL}"'))
PY
echo "   ▸ the deploy profile's planned smoke step (its retry loop around the same command), on the local Worker"
(E2E_LOCAL_URL="$url" bash "$scratch/smoke-step.sh") > "$scratch/smoke-step.log" 2>&1 \
  || { echo "FAIL: the planned smoke step refused the blog" >&2; tail -20 "$scratch/smoke-step.log" >&2; exit 1; }

echo "   ▸ every route the blog promises"
python3 - "$url" "$values" <<'PY'
import html, json, re, sys, urllib.error, urllib.request
base, values = sys.argv[1], json.load(open(sys.argv[2]))
name = values["productname"]
problems = []
def bad(m): problems.append(m)
def get(path):
    try:
        with urllib.request.urlopen(base + path, timeout=60) as r:
            return r.status, r.headers.get("content-type", ""), r.read()
    except urllib.error.HTTPError as e:
        return e.code, e.headers.get("content-type", ""), e.read()
def text(fragment):
    return html.unescape(re.sub(r"<[^>]+>", "", fragment)).strip()
def title(page):
    m = re.search(r"<title>(.*?)</title>", page, re.S)
    return html.unescape(m.group(1)) if m else None
NOTICE = 'data-sanity-notice="unconnected"'
POSTS = {"connect-your-sanity-project": "Connect your Sanity project",
         "writing-in-the-studio": "Writing in the Studio",
         "rendered-at-the-edge": "Rendered at the edge"}

# The home page: the blog's own name, the notice, and every sample post.
s, ctype, body = get("/")
page = body.decode()
if s != 200 or not ctype.startswith("text/html"):
    bad(f"/ answered {s} {ctype}")
h1 = re.search(r"<h1[^>]*>(.*?)</h1>", page, re.S)
if not h1 or text(h1.group(1)) != name:
    bad(f"the home page's heading is {h1 and text(h1.group(1))!r}, not {name!r}")
if title(page) != name:
    bad(f"the home page's <title> is {title(page)!r}, not {name!r}")
if NOTICE not in page or 'href="/posts/connect-your-sanity-project"' not in page:
    bad("the home page does not say the blog is unconnected, or where to connect it")
links = set(re.findall(r'href="/posts/([^"]+)"', page))
if links != set(POSTS):
    bad(f"the home page links the posts {sorted(links)}, not the samples {sorted(POSTS)}")
if "More Stories" not in page:
    bad("the home page has no More Stories section")
if 'href="https://github.com/vercel/next.js/tree/canary/examples/cms-sanity"' not in page:
    bad("the footer's link to the upstream template is gone or renamed")
if ">Blog.<" in page or title(page) == "Blog.":
    bad("the home page still carries the baseline's name")

# Each sample post, under the blog's name, with the notice.
for slug, post_title in POSTS.items():
    s, _, body = get(f"/posts/{slug}")
    p = body.decode()
    h1 = re.search(r"<h1[^>]*>(.*?)</h1>", p, re.S)
    if s != 200:
        bad(f"/posts/{slug} answered {s}")
        continue
    if not h1 or text(h1.group(1)) != post_title:
        bad(f"/posts/{slug}'s heading is {h1 and text(h1.group(1))!r}, not {post_title!r}")
    if title(p) != f"{post_title} | {name}":
        bad(f"/posts/{slug}'s <title> is {title(p)!r}, not '{post_title} | {name}'")
    if NOTICE not in p:
        bad(f"/posts/{slug} does not carry the unconnected notice")
s, _, body = get("/posts/connect-your-sanity-project")
for words in ("SANITY_PROJECT_ID", "SANITY_DATASET", "SANITY_API_READ_TOKEN", "CORS"):
    if words not in body.decode():
        bad(f"the connect post does not mention {words}")

for path, want in (("/posts/no-such-post", 404), ("/no-such-page", 404)):
    s, _, _ = get(path)
    if s != want:
        bad(f"{path} answered {s}, want {want}")

# The Studio's route: the connect page, not a Studio with no project behind it.
for path in ("/studio", "/studio/structure"):
    s, _, body = get(path)
    p = body.decode()
    if s != 200 or NOTICE not in p or "Connect your Sanity project" not in p:
        bad(f"{path} answered {s} without the connect page")
    if 'name="robots" content="noindex"' not in p:
        bad(f"{path} is indexable")

# Static assets, served by the Worker's ASSETS binding.
s, ctype, _ = get("/favicon.ico")
if s != 200 or not ctype.startswith("image/"):
    bad(f"/favicon.ico answered {s} {ctype}")
chunk = re.search(r'src="(/_next/static/[^"]+\.js)"', page)
if not chunk:
    bad("the home page loads no script from /_next/static")
else:
    s, ctype, _ = get(chunk.group(1))
    if s != 200 or "javascript" not in ctype:
        bad(f"{chunk.group(1)} answered {s} {ctype}")

# THE ROUTE ONLY THE WORKER ANSWERS: draft mode is server code. With no
# project and no token it refuses, with the reason — never a 500.
for q in ("", "?sanity-preview-secret=guess&sanity-preview-pathname=/"):
    s, ctype, body = get("/api/draft-mode/enable" + q)
    if s != 401 or "not connected to a Sanity project" not in body.decode():
        bad(f"/api/draft-mode/enable{q} answered {s} {body[:80]!r}, want 401 and the reason")

if problems:
    for p in problems:
        print(f"  ✕ {p}", file=sys.stderr)
    sys.exit(1)
print(f"   /, the three sample posts, two 404s, /studio (the connect page), the static assets")
print(f"   and draft mode's 401 — the blog's own, named {name!r}, unconnected and saying so")
PY

echo "e2e.test.sh: ok"
