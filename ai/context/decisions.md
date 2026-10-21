# cms-sanity — decisions

The choices that shape this repository, one line each, with where the full
reasoning lives. Superseded decisions stay listed, marked, so the history
reads in order.

| # | Decision | Why | Source |
|---|---|---|---|
| 1 | OpenNext on Workers + Static Assets (`cloudflare-workers-assets-turbo`), the static-assets incremental cache; no R2 or Durable Object cache | Nothing in the Worker is revalidated | `specs/epics/cms-sanity/README.md`, design.md §2 |
| 2 | Blog routes `force-dynamic` + `fetchCache = "force-no-store"`; Sanity's API CDN (60 s) is the cache | Time-based ISR needs a writable cache the static-assets one is not; the CDN's TTL was what the ISR interval matched | risk CS-A |
| 3 | The Studio loads client-side (`next/dynamic`, `ssr: false`), its layout's metadata written out | Rendered on the server it put 7 MB gzip in the Worker; client-side the Worker is 1.6 MB gzip | risk CS-B |
| 4 | Sanity on its Next 16 lines (next-sanity 13, sanity 6), and Tailwind 4, CSS-first | Upstream's lines do not declare Next 16; Studio v6's stylesheet uses cascade layers Tailwind 3 rejects | risks CS-C, CS-E |
| 5 | The unconnected blog: no Sanity project at build serves bundled samples, a notice, a connect page and draft mode's 401 — nothing throws | The platform brokers Cloudflare, not Sanity, so a bootstrap deploys before the owner has a project (CS3) | design.md §6, risks CS-G, CS-J |
| 6 | Project id and dataset are `optionalSecretEnv`, read at build; the read token is an optional Worker secret | A required ref fails the lane before its first step on a fresh product; a deploy never touches a Worker secret | IMPLEMENTATION-STATUS (CS3) |
| 7 | Setting a Sanity secret redeploys nothing; the owner bumps the `# orun: redeploy` stamp in `apps/web/component.yaml` | `orun plan --changed` plans a component only when its files change | risk CS-K |
| 8 | The Cloudflare Web Analytics beacon in place of Speed Insights, opt-in by token | Speed Insights has no Cloudflare twin; the beacon reports Core Web Vitals | risk CS-F |
| 9 | Two phases, one landing (`01-product`, `02-docs`), no infra component | A landing has a fixed cost (cirrus-baseline since baseline-v22); the blog provisions nothing | design.md §6 |
| 10 | `ci.yml` plans nothing while `intent.yaml` names `ws_CHANGE_ME` (replaced the `ORUN_CI` gate); stack-tectonic 0.19.0, not 0.20.0 | A bootstrap cannot set a repository variable; Turbopack refuses 0.20.0's out-of-tree `node_modules` | IMPLEMENTATION-STATUS (CS3) |
| 11 | orun is pinned only where it runs (the `orun-action` `version:` in each workflow); no kiox | `kiox.yaml` pinned a version nothing ran | IMPLEMENTATION-STATUS (CS4) |
| 12 | Component docs are generated from the manifests and checked in CI | A hand-written copy of the dependency graph and bindings drifts silently | `tooling/catalog/gen-component-docs.py` |
| 13 | The workers.dev subdomain is read from the Cloudflare connection (`from: connection.cloudflare.workersSubdomain`), not asked; only a hand-run build passes `--set subdomain` | It belongs to the account like its id and has one right answer; a typed one could only be wrong, and wrong showed up after deploy in the smoke and the probes (cirrus-baseline since baseline-v23) | IMPLEMENTATION-STATUS (CS-6) |
