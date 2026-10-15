# Epic: cms-sanity (CS)

**Vercel's Blog with Sanity CMS is the first of the content-site ports whose content is not in the repository: posts, authors and the site settings live in a Sanity dataset and come back over GROQ, draft mode turns the same pages into a live preview for the embedded Studio, and the Studio itself is a 10 MB browser application mounted at `/studio`. Three of those lean on Vercel-specific things — time-based ISR to keep the blog fresh, a server-rendered Studio page nobody minds on a Lambda, and Speed Insights — and all three have a Cloudflare answer: the blog renders on request against Sanity's API CDN (whose 60 s TTL was what the ISR interval matched), the Studio mounts client-side so it ships as static assets and leaves the Worker bundle at 1.6 MB gzip, and the analytics script is the Cloudflare Web Analytics beacon.**

The upstream code stays the code: the GROQ queries, the schemas, the Portable Text renderer, the Presentation-tool configuration, draft mode and the enable route, TypeGen at `prebuild`. Sanity stays the SaaS it is — a project id and a dataset at build time, a read token as a Worker secret. The port adds the Workers build, the monorepo wrapper, a test package for the image URL builder, the date component and the draft-mode route, and the deploy contract. Departures are small and recorded: the blog routes are `force-dynamic` (so `generateStaticParams` goes), the Studio page loads client-side only, Tailwind 4 instead of 3 (Studio v6's stylesheet uses cascade layers Tailwind 3 rejects), and the Sanity packages move to the lines that declare Next 16.

## Status

| Field | Value |
|-------|-------|
| Status | Draft |
| Cluster | **CS** (CS0–CS2) |
| Owner(s) | `apps/web` (the blog and the Studio) · `tests/web` (image URLs, the date component, the draft-mode route) |
| Builds on | `cirrus-baseline` conventions; the `portfolio-starter-kit` port's build shape (static-assets incremental cache + `populateCache`) and its analytics beacon; the `turso-starter` port's `force-dynamic` answer to a read-only cache |
| Upstream | [vercel/next.js `examples/cms-sanity`](https://github.com/vercel/next.js/tree/canary/examples/cms-sanity) at `a871df1` (2026-10-14) |
| Changes | Adds the Workers build, the monorepo wrapper, tests and the deploy contract; makes the blog routes dynamic; mounts the Studio client-side; swaps Speed Insights for one Cloudflare beacon; moves next-sanity/sanity to their Next 16 lines and Tailwind to 4 |
| Decisions locked | (1) OpenNext on Workers + Static Assets, the static-assets incremental cache. (2) Blog routes `force-dynamic` + `fetchCache = "force-no-store"`; Sanity's API CDN is the cache; no R2/DO cache. (3) The Studio loads through `next/dynamic` with `ssr: false`; the Studio layout's metadata is written out, not re-exported. (4) Project id and dataset are build-time values exported by the Orun build from the product's secrets; the read token is a Worker secret. (5) Tailwind 4, CSS-first. |
| Gate | CS1 is the first user-visible rung. |
| Shipped as | |

## Read order

1. `design.md` — what maps to what, the build, what is out of scope
2. `implementation-plan.md` — the milestones and what "done" means for each
3. `risks-and-open-questions.md` — what could go wrong and what was decided
4. `IMPLEMENTATION-STATUS.md` — what actually shipped (kept distinct from intent)

## Milestones at a glance

| Milestone | What it lands | Done when |
|---|---|---|
| CS0 — the spec | this doc set and the task contracts | merged on `main` |
| CS1 — the blog on Workers | `apps/web` built by OpenNext, `tests/web`, green checks | `wrangler dev` serves the Studio shell, its chunks, a 401 and a 404; the Worker bundle holds no Studio code; Checks green |
| CS2 — ready to instantiate | README, as-built status | a reader can run, test, preview and deploy it against their own Sanity project |
