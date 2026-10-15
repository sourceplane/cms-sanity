import Link from "next/link";

import { SITE_NAME } from "@/app/site";

/**
 * What /studio shows while the build has no Sanity project id: a Studio with
 * no project behind it can only fail, so this says how to give it one.
 */
export default function ConnectStudio() {
  return (
    <main
      data-sanity-notice="unconnected"
      className="mx-auto flex min-h-screen max-w-xl flex-col justify-center gap-4 px-6 py-16"
    >
      <h1 className="text-3xl font-bold tracking-tight">
        Connect your Sanity project
      </h1>
      <p>
        The Studio for {SITE_NAME} opens here once the site is built with a
        Sanity project id. Until then the blog shows sample posts.
      </p>
      <ol className="list-decimal space-y-2 pl-6">
        <li>
          Create a project and a dataset at{" "}
          <a className="underline" href="https://www.sanity.io/manage">
            sanity.io/manage
          </a>
          .
        </li>
        <li>
          Store its id and dataset as the secrets{" "}
          <code>SANITY_PROJECT_ID</code> and <code>SANITY_DATASET</code> for
          each environment, then redeploy the web app.
        </li>
        <li>
          Add this site&apos;s URL to the project&apos;s CORS origins, with
          credentials allowed.
        </li>
      </ol>
      <p>
        <Link className="underline" href="/posts/connect-your-sanity-project">
          The full steps
        </Link>{" "}
        are on the blog.
      </p>
    </main>
  );
}
