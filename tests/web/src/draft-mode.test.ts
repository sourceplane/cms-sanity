import { beforeAll, beforeEach, describe, expect, it, vi } from "vitest";

// `server-only` throws outside a React Server Components bundler; the token
// module imports it for the guarantee, not for behaviour.
vi.mock("server-only", () => ({}));

const { draftModeStore, cookieStore, cookieJar, fetch, client } = vi.hoisted(() => {
  const draftModeStore = { isEnabled: false, enable: vi.fn(), disable: vi.fn() };
  const cookieJar = new Map<string, string>();
  const cookieStore = {
    get: vi.fn((name: string) =>
      cookieJar.has(name) ? { name, value: cookieJar.get(name) } : undefined,
    ),
    set: vi.fn((cookie: { name: string; value?: string }) => {
      cookieJar.set(cookie.name, cookie.value ?? "");
    }),
    delete: vi.fn((cookie: { name: string }) => {
      cookieJar.delete(cookie.name);
    }),
  };
  // The Sanity client, mocked: `fetch` answers the preview-secret query.
  const fetch = vi.fn();
  type FakeClient = {
    config: () => { token: string };
    withConfig: () => FakeClient;
    fetch: typeof fetch;
  };
  const client: FakeClient = {
    config: () => ({ token: "test-token" }),
    withConfig: () => client,
    fetch,
  };
  return { draftModeStore, cookieStore, cookieJar, fetch, client };
});

vi.mock("next/headers", () => ({
  draftMode: async () => draftModeStore,
  cookies: async () => cookieStore,
}));
vi.mock("next/navigation", () => ({
  redirect: (to: string) => new Response(null, { status: 307, headers: { location: to } }),
}));
vi.mock("@/sanity/lib/client", () => ({ client }));

beforeAll(() => {
  process.env.NEXT_PUBLIC_SANITY_PROJECT_ID = "abc123";
  process.env.NEXT_PUBLIC_SANITY_DATASET = "production";
  process.env.SANITY_API_READ_TOKEN = "test-token";
});

beforeEach(() => {
  vi.clearAllMocks();
  cookieJar.clear();
  draftModeStore.isEnabled = false;
});

const enableUrl = (params: Record<string, string>) =>
  `http://localhost:3000/api/draft-mode/enable?${new URLSearchParams(params)}`;

describe("GET /api/draft-mode/enable (apps/web/app/api/draft-mode/enable/route.ts)", () => {
  it("rejects a secret the dataset does not hold", async () => {
    fetch.mockResolvedValueOnce({ private: null, public: null });
    const { GET } = await import("@/app/api/draft-mode/enable/route");
    const res = await GET(
      new Request(
        enableUrl({ "sanity-preview-secret": "nope", "sanity-preview-pathname": "/posts/hello" }),
      ),
    );
    expect(res.status).toBe(401);
    expect(await res.text()).toBe("Invalid secret");
    expect(draftModeStore.enable).not.toHaveBeenCalled();
    // The secret is looked up through the token-bearing client.
    expect(fetch).toHaveBeenCalledWith(
      expect.stringContaining("previewUrlSecret"),
      { secret: "nope" },
      expect.anything(),
    );
  });

  it("rejects a request that carries no secret at all", async () => {
    const { GET } = await import("@/app/api/draft-mode/enable/route");
    const res = await GET(new Request(enableUrl({ "sanity-preview-pathname": "/" })));
    expect(res.status).toBe(401);
    expect(fetch).not.toHaveBeenCalled();
    expect(draftModeStore.enable).not.toHaveBeenCalled();
  });

  it("enables draft mode and redirects to the previewed path for a valid secret", async () => {
    fetch.mockResolvedValueOnce({
      private: {
        _id: "sanity.previewUrlSecret.test",
        _updatedAt: new Date().toISOString(),
        secret: "s3cret",
        studioUrl: "http://localhost:3000/studio",
      },
      public: null,
    });
    const { GET } = await import("@/app/api/draft-mode/enable/route");
    const res = await GET(
      new Request(
        enableUrl({ "sanity-preview-secret": "s3cret", "sanity-preview-pathname": "/posts/hello" }),
      ),
    );
    expect(draftModeStore.enable).toHaveBeenCalledTimes(1);
    expect(res.status).toBe(307);
    expect(res.headers.get("location")).toBe("/posts/hello");
    expect(cookieStore.set).toHaveBeenCalledWith(
      expect.objectContaining({ name: "__prerender_bypass", httpOnly: true, path: "/" }),
    );
  });
});
