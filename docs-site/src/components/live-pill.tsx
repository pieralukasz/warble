"use client";

import { useEffect, useState } from "react";
import { cn } from "@/lib/cn";

export type PillState = "listening" | "transcribing" | "done";

/** How long each state lasts in the looping demo, in milliseconds. */
const CYCLE: { state: PillState | "hidden"; duration: number }[] = [
  { state: "listening", duration: 3600 },
  { state: "transcribing", duration: 1500 },
  { state: "done", duration: 1400 },
  { state: "hidden", duration: 600 },
];

/** Padding, the red dot and its gap, plus 6px for every waveform bar. */
function width(state: PillState, bars: number) {
  if (state === "transcribing") return 72;
  if (state === "done") return 44;
  return 50 + bars * 6;
}

const LABEL: Record<PillState, string> = {
  listening: "Warble is listening, with a live waveform",
  transcribing: "Warble is transcribing",
  done: "Warble has typed the text",
};

/**
 * The recording pill rebuilt in HTML, so it can move on the page. One glass
 * capsule that changes width like the app's: waveform, then dots, then a
 * check mark. Pass `state` for one fixed state, or leave it out to loop.
 */
export function LivePill({
  state,
  bars = 36,
  className,
}: {
  state?: PillState;
  /** Waveform bars while listening; the pill is as wide as they need. */
  bars?: number;
  className?: string;
}) {
  const cycling = useCycle(state === undefined);
  const current = state ?? (cycling === "hidden" ? "done" : cycling);
  const hidden = state === undefined && cycling === "hidden";

  return (
    <div
      role="img"
      aria-label={LABEL[current]}
      className={cn("warble-pill", hidden && "warble-pill-hidden", className)}
      style={{ width: width(current, bars) }}
    >
      <Layer active={current === "listening"}>
        <span className="warble-pill-dot" />
        <span className="flex h-5 items-center gap-[3px]">
          {Array.from({ length: bars }, (_, index) => (
            <span
              // biome-ignore lint/suspicious/noArrayIndexKey: bars never reorder
              key={index}
              className="warble-pill-bar"
              style={barStyle(index)}
            />
          ))}
        </span>
      </Layer>
      <Layer active={current === "transcribing"}>
        {[0, 1, 2].map((dot) => (
          <span
            key={dot}
            className="warble-pill-thinking"
            style={{ animationDelay: `${dot * 160}ms` }}
          />
        ))}
      </Layer>
      <Layer active={current === "done"}>
        <svg
          viewBox="0 0 24 24"
          className="size-5 text-emerald-500"
          fill="none"
          aria-hidden="true"
        >
          <path
            key={current === "done" ? "drawn" : "idle"}
            className="warble-pill-check"
            d="M5 12.5l4.5 4.5L19 7.5"
            stroke="currentColor"
            strokeWidth="3"
            strokeLinecap="round"
            strokeLinejoin="round"
          />
        </svg>
      </Layer>
    </div>
  );
}

function Layer({
  active,
  children,
}: {
  active: boolean;
  children: React.ReactNode;
}) {
  return (
    <span
      aria-hidden="true"
      className={cn(
        "absolute inset-0 flex items-center justify-center gap-2.5 px-4 transition-[opacity,transform] duration-300",
        active
          ? "opacity-100 scale-100"
          : "pointer-events-none opacity-0 scale-75",
      )}
    >
      {children}
    </span>
  );
}

/** A speech-like spread of heights and speeds, the same on server and client. */
function barStyle(index: number) {
  const envelope =
    0.35 +
    0.65 * Math.abs(Math.sin(index * 0.55) * Math.sin(index * 0.21 + 0.6));
  return {
    height: `${Math.round(6 + envelope * 14)}px`,
    animationDuration: `${620 + ((index * 137) % 420)}ms`,
    animationDelay: `${-((index * 89) % 700)}ms`,
  };
}

/** Steps through CYCLE forever, unless the reader prefers reduced motion. */
function useCycle(enabled: boolean) {
  const [step, setStep] = useState(0);

  useEffect(() => {
    if (!enabled) return;
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    const timer = window.setTimeout(
      () => setStep((current) => (current + 1) % CYCLE.length),
      CYCLE[step].duration,
    );
    return () => window.clearTimeout(timer);
  }, [enabled, step]);

  return CYCLE[step].state;
}

/**
 * A small desktop for the pill to sit on: the looping demo near the bottom,
 * as on a real screen, and each state below it with its caption.
 */
export function PillStage() {
  return (
    <div className="not-prose my-6 space-y-4">
      <div className="warble-desk relative flex h-56 items-end justify-center overflow-hidden rounded-2xl border pb-7">
        <LivePill />
      </div>
      <div className="grid gap-4 sm:grid-cols-3">
        {(
          [
            ["listening", "Listening: live waveform"],
            ["transcribing", "Transcribing"],
            ["done", "Typed"],
          ] as const
        ).map(([state, caption]) => (
          <figure
            key={state}
            className="warble-desk flex flex-col items-center gap-3 rounded-2xl border px-4 pt-8 pb-4"
          >
            <LivePill state={state} bars={18} />
            <figcaption className="text-sm text-fd-muted-foreground">
              {caption}
            </figcaption>
          </figure>
        ))}
      </div>
    </div>
  );
}
