# cms-sanity — where this repository stands

The entry page for anyone (or any agent) picking this repository up. It is
this repository's own state and does not ship to a blog built from it; the
two pages that do are [operations.md](operations.md) and
[deployment.md](deployment.md).

## What it is

Vercel's Blog with Sanity CMS on Cloudflare Workers + Static Assets
(`@opennextjs/cloudflare`) — posts read over GROQ from a Sanity dataset, the
Studio embedded at `/studio` and loaded client-side — packaged as an Orun
baseline: `orun new --blueprint repo-blueprint.yaml` builds a new blog in its
own repository and takes it to live on stage and prod in one landing
(`01-product`), then records what went live (`02-docs`). It deploys before
its owner has a Sanity project: unconnected, the blog serves bundled sample
posts under a "connect your Sanity project" notice. There is no infra
component; Sanity stays the owner's SaaS.

## Release

| | |
|---|---|
| Latest tag | `baseline-v1` (CS3) |
| On `main` since | CS4 — the cirrus standard (no kiox, generated component docs, this context pack) |
| Proven live | No. Everything short of the platform is proven offline in Baseline CI, unconnected; a live bootstrap (risk CS-M) and a connected blog reading a real dataset, its Presentation preview included (risk CS-H), are still to come |

## Where to read

| Question | Page |
|---|---|
| What shipped, and every departure from upstream | `specs/epics/cms-sanity/IMPLEMENTATION-STATUS.md` |
| Why it is built this way | [decisions.md](decisions.md), then `specs/epics/cms-sanity/design.md` |
| What could still go wrong | [open-risks.md](open-risks.md), then `specs/epics/cms-sanity/risks-and-open-questions.md` |
| How to instantiate it | `BOOTSTRAP.md`, `docs/phases/` |
| What each component is | `apps/web/docs/`, `tests/web/docs/` (generated; `python3 tooling/catalog/gen-component-docs.py`) |

## Next

1. Bootstrap one blog from the next tag against a workspace, and record its
   timings (closes CS-M).
2. Connect a Sanity project to it, see the samples give way, and open the
   Presentation tool once to confirm the preview loads (closes CS-H).
3. Cut the next `baseline-vN` with `tag.yml` so the registry can pin CS4.
