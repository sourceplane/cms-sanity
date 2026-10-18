# cms-sanity — open risks

What is not yet proven or not yet decided. The full write-up of every risk,
including the accepted and resolved ones, is
`specs/epics/cms-sanity/risks-and-open-questions.md`; this page lists only
what is still live, so it should be short.

| ID | Risk | State | What closes it |
|---|---|---|---|
| CS-M | Not proven live: repository creation, the brokered token, a real deploy and the probes, and a connected blog reading a real dataset through the Worker | OPEN | One bootstrap from a tag against a workspace, then a Sanity project connected to it |
| CS-H | Draft-mode cookies inside the Presentation iframe (`SameSite=None; Partitioned` on workers.dev) are tested with a mocked client, never in a browser against a Sanity project | OPEN | The first connected product opens the Presentation tool once and confirms the preview loads |

Accepted, and worth knowing before you change them: CS-F (Speed Insights has
no one-to-one twin), CS-I (upstream's perspective precedence, kept as
written), CS-K (setting a secret redeploys nothing), CS-L (a connected blog
with a wrong project answers 500, unmasked).
