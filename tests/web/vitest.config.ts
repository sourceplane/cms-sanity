import { defineConfig } from "vitest/config";
import * as path from "node:path";

export default defineConfig({
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "../../apps/web"),
    },
  },
  test: {
    include: ["src/**/*.test.ts", "src/**/*.test.tsx"],
    environment: "node",
    server: {
      deps: {
        // Transformed rather than loaded natively, so the test's mocks of
        // `next/headers` and `next/navigation` reach its imports.
        inline: ["next-sanity"],
      },
    },
  },
});
