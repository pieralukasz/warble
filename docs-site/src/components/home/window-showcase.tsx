"use client";

import { useState } from "react";
import { asset } from "@/lib/shared";

const PANES = [
  {
    name: "History",
    image: "history",
    width: 1920,
    height: 1280,
    alt: "Warble’s History pane: dictations grouped by day, each with the app it went into, its word count and length",
    fact: "Searchable and grouped by day, with the app each dictation went into, its length and optional audio replay.",
    field: "green",
  },
  {
    name: "Dictionary",
    image: "dictionary",
    width: 1920,
    height: 1280,
    alt: "Warble’s Dictionary pane with words such as Kubernetes and SwiftUI, and replacements such as my email",
    fact: "Words fix spellings like Kubernetes and SwiftUI. Replacements turn “my email” into the address.",
    field: "teal",
  },
  {
    name: "Settings",
    image: "settings",
    width: 1920,
    height: 1280,
    alt: "Warble’s Settings pane with the hotkey, mode, language and spoken punctuation",
    fact: "Your key, Hold or Toggle, the language, spoken punctuation, sounds and the pill. It saves as you go.",
    field: "mint",
  },
  {
    name: "Menu bar",
    image: "menubar",
    width: 692,
    height: 692,
    alt: "The Warble menu bar panel: status, the last dictation with a copy button, and round toggles for language, mode, pill and sounds",
    fact: "Status, your last dictation with a copy button, and round toggles in the style of Control Center.",
    field: "night",
  },
] as const;

/**
 * The app's own window, shown one pane at a time on the capsule. The list is
 * the window's sidebar; choosing a name swaps the screenshot and the field.
 */
export function WindowShowcase() {
  const [active, setActive] = useState(0);
  const pane = PANES[active];

  return (
    <div className="wb-show" data-field={pane.field}>
      <div className="wb-show-stage">
        <div className="wb-show-capsule" aria-hidden="true" />
        {PANES.map((item, index) => (
          // biome-ignore lint/performance/noImgElement: static export serves plain files
          <img
            key={item.name}
            src={asset(`/screenshots/${item.image}.png`)}
            width={item.width}
            height={item.height}
            alt={item.alt}
            loading="lazy"
            decoding="async"
            className={`wb-show-shot ${item.image === "menubar" ? "is-square" : ""} ${index === active ? "is-active" : ""}`}
            aria-hidden={index === active ? undefined : true}
          />
        ))}
      </div>

      <div className="wb-show-list">
        <h2 className="wb-show-heading">One window</h2>
        <ul>
          {PANES.map((item, index) => (
            <li key={item.name}>
              <button
                type="button"
                className={`wb-show-name ${index === active ? "is-active" : ""}`}
                aria-pressed={index === active}
                onClick={() => setActive(index)}
              >
                {item.name}
              </button>
            </li>
          ))}
        </ul>
      </div>

      <p className="wb-show-fact" aria-live="polite">
        {pane.fact}
      </p>
    </div>
  );
}
