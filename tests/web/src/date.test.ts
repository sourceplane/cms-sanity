import { describe, expect, it } from "vitest";
import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";

describe("DateComponent (apps/web/app/(blog)/date.tsx)", () => {
  it("renders a <time> carrying the ISO value and the long month, day and year", async () => {
    const { default: DateComponent } = await import("@/app/(blog)/date");
    // A local-time ISO string, so the calendar day is the same in every zone.
    const html = renderToStaticMarkup(
      createElement(DateComponent, { dateString: "2024-10-01T12:00:00" }),
    );
    // The template's format string is `LLLL<tab>d, yyyy`, tab included.
    expect(html).toBe('<time dateTime="2024-10-01T12:00:00">October\t1, 2024</time>');
  });
});
