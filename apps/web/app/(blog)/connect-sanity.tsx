import Link from "next/link";

/**
 * Shown above every blog page while the build has no Sanity project id: the
 * posts below it are the bundled samples (sanity/lib/sample.ts), and this says
 * so, and where the steps to connect a project are. Gone once one is set.
 */
export default function ConnectSanityNotice() {
  return (
    <div
      role="status"
      data-sanity-notice="unconnected"
      className="border-b border-amber-200 bg-amber-50 text-amber-950"
    >
      <p className="container mx-auto px-5 py-3 text-center text-sm">
        <strong>Sample content.</strong> This blog is not connected to a Sanity
        project yet.{" "}
        <Link
          href="/posts/connect-your-sanity-project"
          className="font-semibold underline hover:text-amber-700"
        >
          Connect your Sanity project
        </Link>{" "}
        to publish your own posts.
      </p>
    </div>
  );
}
