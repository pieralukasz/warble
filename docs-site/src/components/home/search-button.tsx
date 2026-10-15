"use client";

import { useSearchContext } from "fumadocs-ui/contexts/search";

/** Opens the docs search dialog (also on Cmd/Ctrl+K). */
export function SearchButton({ className }: { className?: string }) {
  const { enabled, setOpenSearch } = useSearchContext();
  if (!enabled) return null;
  return (
    <button
      type="button"
      className={className}
      onClick={() => setOpenSearch(true)}
    >
      Search
    </button>
  );
}
