import { beforeAll, describe, expect, it, vi } from "vitest";

// sanity/lib/api.ts reads the project id and dataset when it is imported
// (and throws without them), so they are set before any module loads.
beforeAll(() => {
  process.env.NEXT_PUBLIC_SANITY_PROJECT_ID = "abc123";
  process.env.NEXT_PUBLIC_SANITY_DATASET = "production";
});

const picture = {
  asset: { _ref: "image-Tb9Ew8CXIwaY6R1kjMvI0uRR-2000x3000-jpg" },
  alt: "A portrait",
};

describe("image URLs (apps/web/sanity/lib/utils.ts)", () => {
  it("builds a Sanity CDN URL for an image reference, as the avatar does", async () => {
    const { urlForImage } = await import("@/sanity/lib/utils");
    const url = new URL(urlForImage(picture)!.height(96).width(96).fit("crop").url());
    expect(url.origin + url.pathname).toBe(
      "https://cdn.sanity.io/images/abc123/production/Tb9Ew8CXIwaY6R1kjMvI0uRR-2000x3000.jpg",
    );
    expect(url.searchParams.get("w")).toBe("96");
    expect(url.searchParams.get("h")).toBe("96");
    expect(url.searchParams.get("fit")).toBe("crop");
    expect(url.searchParams.get("auto")).toBe("format");
  });

  it("returns nothing for a source without an asset reference", async () => {
    const { urlForImage } = await import("@/sanity/lib/utils");
    expect(urlForImage(undefined)).toBeUndefined();
    expect(urlForImage({ alt: "no asset yet" })).toBeUndefined();
  });

  it("resolves an Open Graph image at 1200×627, cropped", async () => {
    const { resolveOpenGraphImage } = await import("@/sanity/lib/utils");
    const og = resolveOpenGraphImage(picture);
    expect(og).toMatchObject({ alt: "A portrait", width: 1200, height: 627 });
    const url = new URL(og!.url);
    expect(url.searchParams.get("w")).toBe("1200");
    expect(url.searchParams.get("h")).toBe("627");
    expect(url.searchParams.get("fit")).toBe("crop");
    expect(resolveOpenGraphImage(undefined)).toBeUndefined();
  });

  it("resolves hrefs for posts only", async () => {
    const { resolveHref } = await import("@/sanity/lib/utils");
    const warn = vi.spyOn(console, "warn").mockImplementation(() => {});
    expect(resolveHref("post", "hello-world")).toBe("/posts/hello-world");
    expect(resolveHref("post")).toBeUndefined();
    expect(resolveHref("author", "jane")).toBeUndefined();
    expect(warn).toHaveBeenCalledWith("Invalid document type:", "author");
    warn.mockRestore();
  });
});
