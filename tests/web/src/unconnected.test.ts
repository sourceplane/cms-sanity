import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

// A blog built with no Sanity project — what every fresh deploy is until its
// owner connects one — must render its sample posts and refuse draft mode
// with a reason, never reach Sanity and never fail with a 500.

vi.mock("server-only", () => ({}));
vi.mock("next/headers", () => ({
  draftMode: async () => ({ isEnabled: false, enable: vi.fn(), disable: vi.fn() }),
  cookies: async () => ({ get: vi.fn(), set: vi.fn(), delete: vi.fn() }),
}));

const SANITY_ENV = [
  "NEXT_PUBLIC_SANITY_PROJECT_ID",
  "NEXT_PUBLIC_SANITY_DATASET",
  "SANITY_API_READ_TOKEN",
] as const;
const saved: Record<string, string | undefined> = {};

beforeEach(() => {
  for (const k of SANITY_ENV) {
    saved[k] = process.env[k];
    delete process.env[k];
  }
  vi.resetModules();
});
afterEach(() => {
  for (const k of SANITY_ENV) {
    if (saved[k] === undefined) delete process.env[k];
    else process.env[k] = saved[k];
  }
  vi.restoreAllMocks();
});

describe("the project configuration (apps/web/sanity/lib/api.ts)", () => {
  it("is unconnected with no project id, and imports without throwing", async () => {
    const api = await import("@/sanity/lib/api");
    expect(api.isSanityConfigured).toBe(false);
    expect(api.dataset).toBe("production");
  });

  it("treats the old build placeholder as no project", async () => {
    process.env.NEXT_PUBLIC_SANITY_PROJECT_ID = "placeholder";
    const api = await import("@/sanity/lib/api");
    expect(api.isSanityConfigured).toBe(false);
  });

  it("is connected with a project id; the dataset defaults to production", async () => {
    process.env.NEXT_PUBLIC_SANITY_PROJECT_ID = "abc123";
    const api = await import("@/sanity/lib/api");
    expect(api.isSanityConfigured).toBe(true);
    expect(api.projectId).toBe("abc123");
    expect(api.dataset).toBe("production");
    process.env.NEXT_PUBLIC_SANITY_DATASET = "staging";
    vi.resetModules();
    expect((await import("@/sanity/lib/api")).dataset).toBe("staging");
  });

  it("has no read token, and that is not an error", async () => {
    const { token } = await import("@/sanity/lib/token");
    expect(token).toBeUndefined();
  });
});

describe("sanityFetch without a project (apps/web/sanity/lib/fetch.ts)", () => {
  it("answers every query from the sample posts and never calls Sanity", async () => {
    const { client } = await import("@/sanity/lib/client");
    const fetch = vi.spyOn(client, "fetch").mockRejectedValue(new Error("Sanity was called"));
    const { sanityFetch } = await import("@/sanity/lib/fetch");
    const q = await import("@/sanity/lib/queries");
    const { samplePosts } = await import("@/sanity/lib/sample");

    expect(await sanityFetch({ query: q.settingsQuery })).toBeNull();

    const hero = await sanityFetch({ query: q.heroQuery });
    expect(hero?.slug).toBe("connect-your-sanity-project");
    expect(hero?.content?.length).toBeGreaterThan(0);

    const more = await sanityFetch({ query: q.moreStoriesQuery, params: { skip: hero!._id, limit: 100 } });
    expect(more.map((p) => p.slug)).toEqual(["writing-in-the-studio", "rendered-at-the-edge"]);
    expect(more.every((p) => !("content" in p))).toBe(true);
    const two = await sanityFetch({ query: q.moreStoriesQuery, params: { skip: "none", limit: 2 } });
    expect(two).toHaveLength(2);

    const post = await sanityFetch({ query: q.postQuery, params: Promise.resolve({ slug: "writing-in-the-studio" }) });
    expect(post?.title).toBe("Writing in the Studio");
    expect(await sanityFetch({ query: q.postQuery, params: { slug: "no-such-post" } })).toBeNull();

    expect(fetch).not.toHaveBeenCalled();
    // Newest first, as the queries order them, each with a unique slug and id.
    const dates = samplePosts.map((p) => p.date);
    expect([...dates].sort().reverse()).toEqual(dates);
    expect(new Set(samplePosts.map((p) => p.slug)).size).toBe(samplePosts.length);
  });

  it("says how to connect a project in the first post, naming the settings the README documents", async () => {
    const { samplePosts } = await import("@/sanity/lib/sample");
    const text = JSON.stringify(samplePosts[0]?.content);
    for (const words of ["SANITY_PROJECT_ID", "SANITY_DATASET", "SANITY_API_READ_TOKEN", "CORS"]) {
      expect(text).toContain(words);
    }
  });
});

describe("GET /api/draft-mode/enable without a project or a token", () => {
  const url = "http://localhost:3000/api/draft-mode/enable?sanity-preview-secret=x&sanity-preview-pathname=/";

  it("refuses with 401 and the reason when no project is connected", async () => {
    const { GET } = await import("@/app/api/draft-mode/enable/route");
    const res = await GET(new Request(url));
    expect(res.status).toBe(401);
    expect(await res.text()).toMatch(/not connected to a Sanity project/);
  });

  it("refuses with 401 and the reason when the project has no read token", async () => {
    process.env.NEXT_PUBLIC_SANITY_PROJECT_ID = "abc123";
    const { GET } = await import("@/app/api/draft-mode/enable/route");
    const res = await GET(new Request(url));
    expect(res.status).toBe(401);
    expect(await res.text()).toMatch(/SANITY_API_READ_TOKEN/);
  });
});
