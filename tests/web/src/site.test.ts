import { describe, expect, it } from "vitest";

describe("site identity (apps/web/app/site.ts)", () => {
  it("names the blog, and the blog's fallback title is that name", async () => {
    const { SITE_NAME } = await import("@/app/site");
    const demo = await import("@/sanity/lib/demo");
    expect(SITE_NAME.trim()).not.toBe("");
    expect(demo.title).toBe(SITE_NAME);
  });

  it("signs the sample posts with it", async () => {
    const { SITE_NAME } = await import("@/app/site");
    const { samplePosts } = await import("@/sanity/lib/sample");
    expect(samplePosts.every((p) => p.author?.name === SITE_NAME)).toBe(true);
  });
});
