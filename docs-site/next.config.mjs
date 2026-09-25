import { createMDX } from "fumadocs-mdx/next";

const withMDX = createMDX();

// GitHub Pages serves the site from /<repository>; the Docs workflow sets this.
const basePath = process.env.DOCS_BASE_PATH ?? "";

/** @type {import('next').NextConfig} */
const config = {
  output: "export",
  reactStrictMode: true,
  basePath,
  env: {
    NEXT_PUBLIC_BASE_PATH: basePath,
  },
};

export default withMDX(config);
