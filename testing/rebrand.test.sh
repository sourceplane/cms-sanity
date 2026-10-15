#!/usr/bin/env bash
# THE REBRAND WRITES EACH VALUE ONCE, AND WHAT IT WROTE STAYS WRITTEN.
#
# Drives the real tooling/rebrand/rebrand.mjs over one-file trees and compares
# the file. Each case is a shape this baseline's identity actually takes in the
# tree — a source link, the site-name seam, the Worker name in wrangler.jsonc
# and the component, the intent's environment URLs, the placeholder domain, the
# Sanity secret refs, and the upstream template's link that shares the slug and
# must NOT be renamed — and each can run through several passes (a re-run of a phase
# re-runs the rebrand over everything already placed, and 02-docs's heal runs
# it again), so a value written by one pass must survive every later one.
#
# The identity is PINNED (fixtures/baseline-identity.cms-sanity.json) rather than
# read from .baseline/identity.json: what this tests is the engine, and its
# fixtures spell the identity out literally.
#
# Needs: node, git. No network.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
rebrand="$here/../tooling/rebrand/rebrand.mjs"
identity="$here/fixtures/baseline-identity.cms-sanity.json"

fail=0
# check NAME VALUES-JSON FILE CONTENT WANT [PASSES]
check() {
  local name="$1" values="$2" file="$3" content="$4" want="$5" passes="${6:-1}"
  local tmp got out i
  tmp="$(mktemp -d)"
  git -C "$tmp" init -q
  mkdir -p "$tmp/$(dirname "$file")" "$tmp/.rebrand"
  printf '%s\n' "$content" > "$tmp/$file"
  printf '%s\n' "$values" > "$tmp/.rebrand/values.json"
  for ((i = 1; i <= passes; i++)); do
    git -C "$tmp" add -A
    if ! out="$(cd "$tmp" && node "$rebrand" --baseline-identity "$identity" --values .rebrand/values.json --allow-dirty 2>&1)"; then
      echo "   ✕  $name: rebrand pass $i failed:" >&2
      printf '%s\n' "$out" | sed 's/^/        /' >&2
      fail=1
      rm -rf "$tmp"
      return
    fi
  done
  got="$(cat "$tmp/$file")"
  rm -rf "$tmp"
  if [ "$got" = "$want" ]; then
    echo "   ok  $name"
  else
    echo "   ✕  $name:" >&2
    echo "        got:  $got" >&2
    echo "        want: $want" >&2
    fail=1
  fi
}

acme='{"reponame":"acme-notes","productname":"Acme Notes","productdomain":"acme.dev","githuborg":"acme-inc","subdomain":"acme","orunWorkspace":"ws_79BDXAZQ"}'

echo "── rebrand: the blog's own identity"
check "a source link names the product's owner and repository" \
  "$acme" README.md \
  'See https://github.com/sourceplane/cms-sanity for the source.' \
  'See https://github.com/acme-inc/acme-notes for the source.'
check "the site-name seam takes the product's name" \
  "$acme" apps/web/app/site.ts 'export const SITE_NAME = "Blog.";' \
  'export const SITE_NAME = "Acme Notes";'
check "…and stays a valid string for a name with an apostrophe and an ampersand" \
  '{"reponame":"sams-notes","productname":"Sam'"'"'s Notes & Links","productdomain":"sam.dev"}' \
  apps/web/app/site.ts 'export const SITE_NAME = "Blog.";' \
  'export const SITE_NAME = "Sam'"'"'s Notes & Links";'
check "the template's word Blog elsewhere is content, and is left alone" \
  "$acme" apps/web/sanity/lib/demo.ts '// A statically generated blog example. Blog.' \
  '// A statically generated blog example. Blog.'
check "the upstream template's directory shares the slug, and is not renamed" \
  "$acme" apps/web/app/layout.tsx \
  'href="https://github.com/vercel/next.js/tree/canary/examples/cms-sanity"' \
  'href="https://github.com/vercel/next.js/tree/canary/examples/cms-sanity"'
check "…nor is it in a setup script's guide link, beside a renamed Worker" \
  "$acme" apps/web/package.json \
  'echo see https://github.com/vercel/next.js/tree/canary/examples/cms-sanity#using-the-sanity-cli; wrangler secret put X --name cms-sanity-web-stage' \
  'echo see https://github.com/vercel/next.js/tree/canary/examples/cms-sanity#using-the-sanity-cli; wrangler secret put X --name acme-notes-web-stage'
check "the Worker name in wrangler.jsonc is re-prefixed" \
  "$acme" apps/web/wrangler.jsonc '  "name": "cms-sanity-web",' \
  '  "name": "acme-notes-web",'
check "the component's worker name is re-prefixed, the environment suffix kept" \
  "$acme" apps/web/component.yaml '    workerName: cms-sanity-web' \
  '    workerName: acme-notes-web'
check "the workers.dev subdomain in the component" \
  "$acme" apps/web/component.yaml '    workersDevSubdomain: your-workers-subdomain' \
  '    workersDevSubdomain: acme'
check "an environment URL in the intent" \
  "$acme" intent.yaml '    url: https://cms-sanity-web-prod.your-workers-subdomain.workers.dev' \
  '    url: https://acme-notes-web-prod.acme.workers.dev'
check "the placeholder domain is the product's domain, not a renamed slug" \
  "$acme" intent.yaml '      BASE_DOMAIN: cms-sanity.example.com' \
  '      BASE_DOMAIN: acme.dev'
check "the repo slug" \
  "$acme" package.json '  "name": "cms-sanity",' \
  '  "name": "acme-notes",'
check "a Sanity secret ref names the product's workspace and project, the environment kept" \
  "$acme" apps/web/component.yaml \
  '    NEXT_PUBLIC_SANITY_PROJECT_ID: "secret://cms-sanity/cms-sanity/{{ .environment }}/SANITY_PROJECT_ID"' \
  '    NEXT_PUBLIC_SANITY_PROJECT_ID: "secret://ws_79BDXAZQ/acme-notes/{{ .environment }}/SANITY_PROJECT_ID"'
check "the Sanity variable names are Sanity's, and are left alone" \
  "$acme" apps/web/.env.example 'NEXT_PUBLIC_SANITY_DATASET=' \
  'NEXT_PUBLIC_SANITY_DATASET='
check "org-owned identity is not renamed" \
  "$acme" intent.yaml 'apiVersion: sourceplane.io/v1 # mail ops@sourceplane.ai' \
  'apiVersion: sourceplane.io/v1 # mail ops@sourceplane.ai'
check "without githuborg a source link keeps the baseline's owner" \
  '{"reponame":"acme-notes","productname":"Acme Notes","productdomain":"acme.dev"}' \
  README.md 'https://github.com/sourceplane/cms-sanity' \
  'https://github.com/sourceplane/acme-notes'

echo "── rebrand: a written value is not rewritten, in any later pass"
contains='{"reponame":"cms-sanity-2","productname":"Blog. 2","productdomain":"cms-sanity.example.com.au","githuborg":"sourceplane","subdomain":"your-workers-subdomain-2"}'
check "a repo slug containing the baseline's slug survives three passes" \
  "$contains" package.json '  "name": "cms-sanity",' \
  '  "name": "cms-sanity-2",' 3
check "a Worker name built on it survives three passes" \
  "$contains" apps/web/wrangler.jsonc '  "name": "cms-sanity-web",' \
  '  "name": "cms-sanity-2-web",' 3
check "a domain containing the baseline's domain survives three passes" \
  "$contains" intent.yaml 'BASE_DOMAIN: cms-sanity.example.com' \
  'BASE_DOMAIN: cms-sanity.example.com.au' 3
check "a subdomain containing the placeholder survives three passes" \
  "$contains" intent.yaml '    url: https://cms-sanity-web-stage.your-workers-subdomain.workers.dev' \
  '    url: https://cms-sanity-2-web-stage.your-workers-subdomain-2.workers.dev' 3
check "a blog name containing the baseline's name survives three passes" \
  "$contains" apps/web/app/site.ts 'export const SITE_NAME = "Blog.";' \
  'export const SITE_NAME = "Blog. 2";' 3
check "the upstream link survives three passes of a slug that contains it" \
  "$contains" apps/web/app/layout.tsx 'href="https://github.com/vercel/next.js/tree/canary/examples/cms-sanity"' \
  'href="https://github.com/vercel/next.js/tree/canary/examples/cms-sanity"' 3
# The fixture the placement and end-to-end gates build with: a slug that ENDS
# in the baseline's, so its Worker is `<…>-cms-sanity-web`.
suffixed='{"reponame":"acme-cms-sanity","productname":"Acme","productdomain":"blog.acme.dev","githuborg":"acme-inc","subdomain":"acme","orunWorkspace":"ws_79BDXAZQ"}'
check "a repo slug ending in the baseline's slug survives three passes" \
  "$suffixed" package.json '  "name": "cms-sanity",' \
  '  "name": "acme-cms-sanity",' 3
check "…and its Worker name" \
  "$suffixed" apps/web/wrangler.jsonc '  "name": "cms-sanity-web",' \
  '  "name": "acme-cms-sanity-web",' 3
check "…and its secret ref" \
  "$suffixed" apps/web/component.yaml '    X: "secret://cms-sanity/cms-sanity/{{ .environment }}/SANITY_DATASET"' \
  '    X: "secret://ws_79BDXAZQ/acme-cms-sanity/{{ .environment }}/SANITY_DATASET"' 3

# --verify runs in every phase. Without the product's values it cannot tell
# the product's own identity from a leftover; with them it can. A real
# leftover must fail it either way.
verify() { # NAME VALUES FILE CONTENT WANT(pass|fail) [--values]
  local name="$1" values="$2" file="$3" content="$4" want="$5" withvalues="${6:-}" tmp got
  tmp="$(mktemp -d)"
  git -C "$tmp" init -q
  mkdir -p "$tmp/$(dirname "$file")" "$tmp/.rebrand"
  printf '%s\n' "$content" > "$tmp/$file"
  printf '%s\n' "$values" > "$tmp/.rebrand/values.json"
  git -C "$tmp" add -A
  if (cd "$tmp" && node "$rebrand" --baseline-identity "$identity" --verify ${withvalues:+--values .rebrand/values.json} >/dev/null 2>&1); then got=pass; else got=fail; fi
  rm -rf "$tmp"
  if [ "$got" = "$want" ]; then echo "   ok  $name"; else echo "   ✕  $name: --verify ${got}ed, want $want" >&2; fail=1; fi
}
echo "── rebrand --verify: the product's own identity is not residue"
verify "given the values, a slug containing the baseline's passes" \
  "$contains" package.json '"name": "cms-sanity-2"' pass --values
verify "without them it cannot know, and fails" \
  "$contains" package.json '"name": "cms-sanity-2"' fail
verify "given the values, a slug ending in the baseline's passes" \
  "$suffixed" apps/web/wrangler.jsonc '"name": "acme-cms-sanity-web"' pass --values
verify "the upstream template's link is not residue" \
  "$acme" apps/web/app/layout.tsx 'href="https://github.com/vercel/next.js/tree/canary/examples/cms-sanity"' pass --values
verify "given the values, a real leftover still fails" \
  "$acme" package.json '"name": "cms-sanity"' fail --values
verify "a leftover Worker name fails" \
  "$acme" apps/web/wrangler.jsonc '"name": "cms-sanity-web"' fail --values
verify "a leftover link to another repository named like it fails" \
  "$acme" README.md 'https://github.com/acme-inc/cms-sanity' fail --values
verify "a leftover code identifier fails (no rule renames it — so nothing may spell it)" \
  "$acme" apps/web/x.ts 'export class CmsSanity {}' fail --values
verify "a clean product passes" \
  "$acme" package.json '"name": "acme-notes"' pass --values

echo "── rebrand: a residue it cannot rename fails the rebrand itself"
tmp="$(mktemp -d)"; git -C "$tmp" init -q; mkdir -p "$tmp/.rebrand" "$tmp/apps/web"
printf '%s\n' "$acme" > "$tmp/.rebrand/values.json"
printf 'const x = "CMS_SANITY_TOKEN"\n' > "$tmp/apps/web/x.ts"
git -C "$tmp" add -A
if (cd "$tmp" && node "$rebrand" --baseline-identity "$identity" --values .rebrand/values.json --allow-dirty >/dev/null 2>&1); then
  echo "   ✕  an unrenamable env-var prefix passed the rebrand" >&2; fail=1
else
  echo "   ok  an unrenamable env-var prefix fails the rebrand, naming the file"
fi
rm -rf "$tmp"

[ "$fail" -eq 0 ] || exit 1
echo "rebrand.test.sh: ok"
