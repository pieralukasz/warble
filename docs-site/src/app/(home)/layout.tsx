import { Figtree, League_Spartan } from "next/font/google";
import "./home.css";

const display = League_Spartan({
  subsets: ["latin", "latin-ext"],
  weight: "700",
  variable: "--wb-font-display",
});

const text = Figtree({
  subsets: ["latin", "latin-ext"],
  weight: ["400", "600"],
  variable: "--wb-font-text",
});

/** The home page has its own look; the docs keep the Fumadocs layout. */
export default function Layout({ children }: LayoutProps<"/">) {
  return (
    <div className={`wb ${display.variable} ${text.variable}`}>{children}</div>
  );
}
