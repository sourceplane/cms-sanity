/**
 * The sample posts a blog with no Sanity project renders.
 *
 * A fresh deploy has no Sanity project behind it — the project id is the
 * owner's to add — and it must still serve a blog, not a 500. So until the
 * build is given a project id (sanity/lib/api.ts), `sanityFetch` answers the
 * blog's four queries from this file instead of from a dataset, with the same
 * result shapes TypeGen derives for them, and the layout shows a notice that
 * the blog is not connected yet. The first post says how to connect it. Once
 * a project id is set, nothing here is read.
 */
import type { QueryParams } from "next-sanity";

import { SITE_NAME } from "@/app/site";
import type { MoreStoriesQueryResult, PostQueryResult } from "@/sanity.types";
import {
  heroQuery,
  moreStoriesQuery,
  postQuery,
  settingsQuery,
} from "@/sanity/lib/queries";

type SamplePost = NonNullable<PostQueryResult>;
type Block = NonNullable<SamplePost["content"]>[number];

let keys = 0;
const key = () => `sample${(keys++).toString(36)}`;

function span(text: string, marks: string[] = []) {
  return { _type: "span" as const, _key: key(), text, marks };
}

function para(...parts: Array<string | { text: string; href: string }>): Block {
  const markDefs: NonNullable<Block["markDefs"]> = [];
  const children = parts.map((part) => {
    if (typeof part === "string") return span(part);
    const mark = key();
    markDefs.push({ _type: "link", _key: mark, href: part.href });
    return span(part.text, [mark]);
  });
  return { _type: "block", _key: key(), style: "normal", markDefs, children };
}

function heading(text: string): Block {
  return { _type: "block", _key: key(), style: "h3", markDefs: [], children: [span(text)] };
}

const author = { name: SITE_NAME, picture: null };

function post(
  slug: string,
  title: string,
  date: string,
  excerpt: string,
  content: Block[],
): SamplePost {
  return {
    _id: `sample.${slug}`,
    status: "published",
    title,
    slug,
    excerpt,
    coverImage: null,
    date,
    author,
    content,
  };
}

/** Newest first, as the queries order them. */
export const samplePosts: SamplePost[] = [
  post(
    "connect-your-sanity-project",
    "Connect your Sanity project",
    "2026-10-15T09:00:00.000Z",
    "These posts ship with the blog so that it renders before any content exists. Connect a Sanity project and it shows yours instead.",
    [
      para(
        "Every post on this page is sample content bundled with the blog, so a fresh deploy has something to show. ",
        "The blog reads its posts, authors and settings from a Sanity dataset; connecting one takes four steps.",
      ),
      heading("1. Create a project"),
      para(
        "Create a project and a dataset at ",
        { text: "sanity.io/manage", href: "https://www.sanity.io/manage" },
        " (or run pnpm run setup in apps/web). Note the project id and the dataset name, usually production.",
      ),
      heading("2. Give the build your project"),
      para(
        "The project id and the dataset are public values the build bakes in. Store them for each environment as ",
        "SANITY_PROJECT_ID and SANITY_DATASET (orun secrets set SANITY_PROJECT_ID --env stage, and the same for prod), ",
        "then redeploy the web app. The README's section on connecting Sanity has the exact commands.",
      ),
      heading("3. Allow the site's origin"),
      para(
        "In the project's API settings, add this site's URL as a CORS origin with credentials allowed, ",
        "so the Studio at /studio can sign you in and edit the dataset.",
      ),
      heading("4. Add a read token for draft mode"),
      para(
        "Published posts need no token. Previewing drafts does: create a Viewer token and set it as the Worker secret ",
        "SANITY_API_READ_TOKEN (wrangler secret put SANITY_API_READ_TOKEN).",
      ),
      para(
        "Once the build has a project id, these sample posts and the notice at the top of the page are gone, ",
        "and the blog shows what you publish.",
      ),
    ],
  ),
  post(
    "writing-in-the-studio",
    "Writing in the Studio",
    "2026-10-08T09:00:00.000Z",
    "The Sanity Studio is part of this site, at /studio: posts, authors and the settings that name the blog.",
    [
      para(
        "The Studio is mounted at /studio and ships with the site as static files. Once the blog is connected to a project, ",
        "sign in there to write posts, add authors, and fill in the Settings document — the blog's title, its description and its footer.",
      ),
      para(
        "The Presentation tool shows the blog beside the editor and updates it as you type: it opens the site in draft mode, ",
        "which reads unpublished changes with the read token. Publish a post and it is live within a minute.",
      ),
    ],
  ),
  post(
    "rendered-at-the-edge",
    "Rendered at the edge",
    "2026-10-01T09:00:00.000Z",
    "A Next.js blog on Cloudflare Workers: every page renders on request against Sanity's API CDN.",
    [
      para(
        "This blog is a Next.js app running on Cloudflare Workers with Static Assets. ",
        "Each page renders when it is requested, against Sanity's API CDN, which serves published content with a 60-second cache — ",
        "so a published change shows up within a minute, with no rebuild and no redeploy.",
      ),
      para(
        "Images are served from Sanity's image CDN, resized on the fly. The Studio's code ships as static assets, ",
        "not inside the Worker, which keeps the Worker small.",
      ),
    ],
  ),
];

// A more-stories row is a post without its body.
function summary(post: SamplePost): MoreStoriesQueryResult[number] {
  const { _id, status, title, slug, excerpt, coverImage, date, author } = post;
  return { _id, status, title, slug, excerpt, coverImage, date, author };
}

/**
 * Answers one of the blog's queries (sanity/lib/queries.ts) from the samples,
 * as the dataset would. There is no Settings document: the layout falls back
 * to the blog's name and the template's description, as it does for an empty
 * dataset.
 */
export function sampleFetch(query: string, params: QueryParams): unknown {
  switch (query) {
    case settingsQuery:
      return null;
    case heroQuery:
      return samplePosts[0] ?? null;
    case moreStoriesQuery: {
      const limit = typeof params.limit === "number" ? params.limit : samplePosts.length;
      return samplePosts
        .filter((p) => p._id !== params.skip)
        .slice(0, limit)
        .map(summary);
    }
    case postQuery:
      return samplePosts.find((p) => p.slug === params.slug) ?? null;
    default:
      return null;
  }
}
