"use client";

import { useEffect } from "react";

/**
 * Reveals each `[data-reveal]` element once, when it scrolls into view.
 * The hidden state only applies once this has run (`.wb.is-ready` in home.css).
 */
export function Reveal() {
  useEffect(() => {
    const root = document.querySelector(".wb");
    const items = document.querySelectorAll<HTMLElement>(".wb [data-reveal]");
    const show = (element: Element) => element.classList.add("is-in");
    if (!("IntersectionObserver" in window)) {
      items.forEach(show);
      return;
    }
    const observer = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) {
          if (!entry.isIntersecting) continue;
          show(entry.target);
          observer.unobserve(entry.target);
        }
      },
      { rootMargin: "0px 0px -10% 0px", threshold: 0.08 },
    );
    for (const item of items) observer.observe(item);
    // Content is hidden only from here on, so a failed script never hides it.
    root?.classList.add("is-ready");
    return () => observer.disconnect();
  }, []);

  return null;
}
