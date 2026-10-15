"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { LivePill } from "@/components/live-pill";

/** The sample dictations from Warble's preview mode (Sources/WarbleKit/Preview/PreviewData.swift). */
const SAMPLES = [
  {
    app: "Mail",
    text: "Can we move the design review to Thursday afternoon? I want the new onboarding flow in front of everyone before we lock the release.",
  },
  {
    app: "Xcode",
    text: "Refactor the recorder so the level meter runs on the audio thread and only publishes to the main actor.",
  },
  {
    app: "Notes",
    text: "Groceries: oat milk, blueberries, sourdough, two lemons and coffee beans.",
  },
  {
    app: "Messages",
    text: "Thanks for the quick turnaround. The Kubernetes migration looks good to me, ship it.",
  },
  {
    app: "Reminders",
    text: "Remind me to book the dentist and renew the car insurance before Friday.",
  },
] as const;

/** DictationController.MINIMUM_RECORDING_SECONDS: shorter taps are ignored. */
const MINIMUM_HOLD_MS = 250;
/** DictationController.CONFIRMATION_SECONDS: how long the check mark stays. */
const CONFIRMATION_MS = 1200;
/** Stand-in for transcription time in this demo; the real time depends on the Mac. */
const DEMO_TRANSCRIBE_MS = 700;

type Phase = "idle" | "listening" | "transcribing" | "done" | "short";

function words(text: string) {
  return text.trim().split(/\s+/).length;
}

/**
 * The hero's live thing: hold the key, let go, and a sample dictation lands
 * at the cursor of the app in front, the way Warble pastes it. No microphone
 * is used. Until someone presses the key, it plays itself.
 */
export function DictationDemo() {
  const [phase, setPhase] = useState<Phase>("done");
  const [index, setIndex] = useState(0);
  const [held, setHeld] = useState<number | null>(null);
  const [touched, setTouched] = useState(false);
  const pressedAt = useRef<number | null>(null);
  const timers = useRef<number[]>([]);

  const clearTimers = useCallback(() => {
    for (const timer of timers.current) window.clearTimeout(timer);
    timers.current = [];
  }, []);

  const later = useCallback((ms: number, run: () => void) => {
    timers.current.push(window.setTimeout(run, ms));
  }, []);

  const finish = useCallback(
    (heldMs: number, next: number) => {
      setHeld(heldMs);
      setPhase("transcribing");
      later(DEMO_TRANSCRIBE_MS, () => {
        setIndex(next);
        setPhase("done");
        later(CONFIRMATION_MS, () => setPhase("idle"));
      });
    },
    [later],
  );

  // Plays one dictation every few seconds until the visitor takes over.
  useEffect(() => {
    if (touched) return;
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    let next = 0;
    const cycle = () => {
      next = (next + 1) % SAMPLES.length;
      setPhase("listening");
      const holdMs = 1800 + (next % 3) * 500;
      later(holdMs, () => finish(holdMs, next));
      later(holdMs + DEMO_TRANSCRIBE_MS + CONFIRMATION_MS + 2200, cycle);
    };
    later(2600, cycle);
    return clearTimers;
  }, [touched, finish, later, clearTimers]);

  const start = () => {
    if (pressedAt.current !== null) return;
    clearTimers();
    setTouched(true);
    pressedAt.current = performance.now();
    setPhase("listening");
  };

  const stop = () => {
    if (pressedAt.current === null) return;
    const heldMs = performance.now() - pressedAt.current;
    pressedAt.current = null;
    if (heldMs < MINIMUM_HOLD_MS) {
      setPhase("short");
      later(2400, () => setPhase("idle"));
      return;
    }
    finish(heldMs, (index + 1) % SAMPLES.length);
  };

  const sample = SAMPLES[index];
  const pillState =
    phase === "listening"
      ? "listening"
      : phase === "transcribing"
        ? "transcribing"
        : "done";
  const pillHidden = phase === "idle" || phase === "short";

  return (
    <div className="wb-demo" data-ui>
      <div className="wb-demo-window" aria-live="polite">
        <div className="wb-demo-titlebar">
          <span className="wb-demo-lights" aria-hidden="true">
            <span />
            <span />
            <span />
          </span>
          <span className="wb-demo-app">{sample.app}</span>
        </div>
        <p
          key={`${index}-${phase === "done" ? "in" : "rest"}`}
          className={`wb-demo-text ${phase === "done" ? "is-pasted" : ""}`}
        >
          {sample.text}
          <span className="wb-demo-caret" aria-hidden="true" />
        </p>
        <p className="wb-demo-meta">
          {sample.app} · {words(sample.text)} words
          {held !== null ? ` · key held ${(held / 1000).toFixed(1)} s` : ""}
        </p>
      </div>

      <div className="wb-demo-pill">
        <LivePill
          state={pillState}
          bars={22}
          className={pillHidden ? "warble-pill-hidden" : undefined}
        />
      </div>

      <div className="wb-demo-control">
        <button
          type="button"
          className={`wb-key ${phase === "listening" ? "is-down" : ""}`}
          aria-label="Hold to dictate a sample sentence"
          onPointerDown={(event) => {
            event.currentTarget.setPointerCapture(event.pointerId);
            start();
          }}
          onPointerUp={stop}
          onPointerCancel={stop}
          onKeyDown={(event) => {
            if (event.key !== " " && event.key !== "Enter") return;
            event.preventDefault();
            if (!event.repeat) start();
          }}
          onKeyUp={(event) => {
            if (event.key !== " " && event.key !== "Enter") return;
            event.preventDefault();
            stop();
          }}
          onContextMenu={(event) => event.preventDefault()}
        >
          <span className="wb-key-label">fn</span>
        </button>
        <p className="wb-demo-hint">
          {phase === "short"
            ? "Too short. Warble ignores taps under a quarter of a second."
            : phase === "listening" && touched
              ? "Listening. Let go to paste."
              : "Hold the key, then let go. Sample text from Warble’s preview mode; no microphone is used."}
        </p>
      </div>
    </div>
  );
}
