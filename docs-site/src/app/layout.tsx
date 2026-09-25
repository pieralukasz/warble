import type { Metadata } from "next";
import { Inter } from "next/font/google";
import { Provider } from "@/components/provider";
import { appName, tagline } from "@/lib/shared";
import "./global.css";

const inter = Inter({
  subsets: ["latin", "latin-ext"],
});

/** DOCS_SITE_URL wins; on Vercel the production domain is set automatically. */
function siteUrl() {
  if (process.env.DOCS_SITE_URL) return process.env.DOCS_SITE_URL;
  const vercelHost = process.env.VERCEL_PROJECT_PRODUCTION_URL;
  return vercelHost ? `https://${vercelHost}` : "http://localhost:3000";
}

export const metadata: Metadata = {
  metadataBase: new URL(siteUrl()),
  title: {
    default: `${appName}: ${tagline}`,
    template: `%s · ${appName}`,
  },
  description:
    "Hold a key, speak, let go. Warble types your words in any Mac app using NVIDIA Parakeet, entirely on your Mac. Free and open source.",
};

export default function Layout({ children }: LayoutProps<"/">) {
  return (
    <html lang="en" className={inter.className} suppressHydrationWarning>
      <body className="flex flex-col min-h-screen">
        <Provider>{children}</Provider>
      </body>
    </html>
  );
}
