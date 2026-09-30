import {
  AppWindow,
  BookA,
  Cpu,
  Heart,
  History,
  Keyboard,
  Lock,
  Mic,
  Sparkles,
  Type,
} from "lucide-react";
import Link from "next/link";
import type { ReactNode } from "react";
import { LivePill } from "@/components/live-pill";
import { Screenshot } from "@/components/screenshot";
import { asset, authorUrl, repoUrl } from "@/lib/shared";

const steps = [
  {
    icon: Keyboard,
    title: "Hold fn",
    text: "Or any key you pick. Warble listens only while it is held.",
  },
  {
    icon: Mic,
    title: "Speak",
    text: "A glass pill shows your voice, so you know it is working.",
  },
  {
    icon: Type,
    title: "Let go",
    text: "Parakeet transcribes on your Mac and the text lands at the cursor.",
  },
];

const features = [
  {
    icon: Cpu,
    title: "Parakeet v3, on-device",
    text: "NVIDIA’s TDT model runs on Apple’s Neural Engine through FluidAudio. 25 European languages, all on your Mac. Downloaded once, then fully offline.",
  },
  {
    icon: AppWindow,
    title: "Works in every app",
    text: "Mail, Slack, Xcode, the browser, a terminal. If it has a text cursor, Warble can type into it.",
  },
  {
    icon: Sparkles,
    title: "Made for macOS 26",
    text: "Native SwiftUI with Liquid Glass. A menu bar app first, with a proper window when you want one.",
  },
  {
    icon: History,
    title: "Searchable history",
    text: "Every dictation is kept on your Mac with the app it went into. Copy it, replay the audio, or delete it.",
  },
  {
    icon: BookA,
    title: "Your own dictionary",
    text: "Fix names and jargon, or turn “my email” into your address. Rules run locally after every dictation.",
  },
  {
    icon: Heart,
    title: "Free, for real",
    text: "No account, no subscription, no word limit. MIT licensed, so you can read and change every line.",
  },
];

const privacyFacts = [
  "Audio is recorded only while the key is held and transcribed in memory.",
  "Text, history and your dictionary are plain JSON files in Application Support.",
  "The only network request is the one-time model download from Hugging Face.",
  "No analytics, no crash reporting, no account. Check the source to be sure.",
];

const comparison = [
  ["Price", "Free forever", "Subscription, or a capped free plan"],
  ["Word limit", "None", "Weekly cap on free plans"],
  ["Where speech is processed", "On your Mac", "Remote servers"],
  ["Account", "None", "Required"],
  ["Works offline", "Yes", "No"],
  ["Source code", "Open, MIT", "Closed"],
];

export default function HomePage() {
  return (
    <main className="flex flex-col">
      <Hero />
      <Section eyebrow="How it works" title="Three moves, no clicks">
        <ol className="grid gap-10 sm:grid-cols-3 sm:gap-8">
          {steps.map((step, index) => (
            <li key={step.title} className="border-t pt-5">
              <div className="flex items-center gap-2 text-sm font-medium text-fd-muted-foreground">
                <step.icon className="size-4 text-fd-primary" />
                Step {index + 1}
              </div>
              <h3 className="mt-3 text-lg font-semibold">{step.title}</h3>
              <p className="mt-1 text-fd-muted-foreground">{step.text}</p>
            </li>
          ))}
        </ol>
      </Section>

      <Section
        eyebrow="Features"
        title="Everything a dictation app should do, and nothing it shouldn’t"
      >
        <ul className="grid gap-x-12 gap-y-9 sm:grid-cols-2">
          {features.map((feature) => (
            <li key={feature.title} className="flex gap-4">
              <feature.icon className="mt-0.5 size-5 shrink-0 text-fd-primary" />
              <div>
                <h3 className="font-semibold">{feature.title}</h3>
                <p className="mt-1 text-sm leading-relaxed text-fd-muted-foreground">
                  {feature.text}
                </p>
              </div>
            </li>
          ))}
        </ul>
      </Section>

      <Section
        eyebrow="A look inside"
        title="History, dictionary and settings in one window"
      >
        <div className="grid gap-6 lg:grid-cols-3">
          <Screenshot
            name="history"
            alt="History screen grouped by day"
            caption="History, grouped by day"
          />
          <Screenshot
            name="dictionary"
            alt="Dictionary with words and replacements"
            caption="Words and replacements"
          />
          <Screenshot
            name="settings"
            alt="Settings form"
            caption="Settings that save as you go"
          />
        </div>
      </Section>

      <Section eyebrow="Privacy" title="What leaves your Mac? Nothing.">
        <div className="grid gap-6 lg:grid-cols-2">
          <ul className="flex flex-col justify-center gap-5">
            {privacyFacts.map((line) => (
              <li key={line} className="flex gap-3">
                <Lock className="mt-0.5 size-5 shrink-0 text-fd-primary" />
                <span>{line}</span>
              </li>
            ))}
          </ul>
          <div className="overflow-hidden border-y">
            <table className="h-full w-full table-fixed text-sm">
              <thead>
                <tr>
                  <th className="w-[38%] px-5 py-3.5 text-left font-medium" />
                  <th className="px-5 py-3.5 text-left font-semibold text-fd-primary">
                    Warble
                  </th>
                  <th className="px-5 py-3.5 text-left font-medium text-fd-muted-foreground">
                    Typical cloud dictation
                  </th>
                </tr>
              </thead>
              <tbody>
                {comparison.map(([label, warble, cloud]) => (
                  <tr key={label} className="border-t">
                    <td className="px-5 py-3.5 text-fd-muted-foreground">
                      {label}
                    </td>
                    <td className="px-5 py-3.5 font-medium">{warble}</td>
                    <td className="px-5 py-3.5 text-fd-muted-foreground">
                      {cloud}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
        <p className="mt-6 text-sm text-fd-muted-foreground">
          Warble is not the only app that keeps speech on your Mac. Handy,
          VoiceInk, Superwhisper and MacWhisper run local models too. Warble’s
          take is a native macOS 26 app on the Neural Engine, free and MIT
          licensed, that does dictation and nothing else.
        </p>
      </Section>

      <section className="mx-auto w-full max-w-3xl px-6 pt-8 pb-32 text-center">
        <h2 className="text-3xl font-bold tracking-tight sm:text-4xl">
          Start talking to your Mac
        </h2>
        <p className="mx-auto mt-4 max-w-xl text-fd-muted-foreground">
          Build it from source in one command. Setup walks you through
          permissions and the model download.
        </p>
        <CallToAction className="mt-8 justify-center" />
      </section>

      <footer className="border-t py-10 text-center text-sm text-fd-muted-foreground">
        <p>
          Made by{" "}
          <a
            className="font-medium text-fd-foreground underline underline-offset-4"
            href={authorUrl}
          >
            Lucas Piera
          </a>
          .
        </p>
        <p className="mt-2">
          MIT licensed. Built on{" "}
          <a
            className="underline"
            href="https://github.com/FluidInference/FluidAudio"
          >
            FluidAudio
          </a>{" "}
          and NVIDIA Parakeet, grown from{" "}
          <a className="underline" href="https://github.com/human37/open-wispr">
            open-wispr
          </a>
          .
        </p>
      </footer>
    </main>
  );
}

function Hero() {
  return (
    <section className="mx-auto flex w-full max-w-4xl flex-col items-center px-6 pt-28 pb-24 text-center sm:pt-36">
      {/* biome-ignore lint/performance/noImgElement: static export serves plain files */}
      <img
        src={asset("/icon-256.png")}
        alt="Warble icon"
        width={64}
        height={64}
        className="mb-10"
      />
      <p className="text-sm font-medium text-fd-muted-foreground">
        Free · Open source · Runs on your Mac
      </p>
      <h1 className="mt-6 text-5xl font-extrabold tracking-tight text-balance sm:text-7xl">
        Hold a key, speak, <span className="text-fd-primary">let go.</span>
      </h1>
      <p className="mt-8 max-w-xl text-lg leading-relaxed text-fd-muted-foreground">
        <span className="font-semibold text-fd-foreground">
          Your voice, typed.
        </span>{" "}
        Warble turns speech into text in any Mac app with NVIDIA Parakeet,
        without the cloud, the account or the subscription.
      </p>
      <CallToAction className="mt-10 justify-center" />
      <div className="mt-20 flex h-28 w-full max-w-md items-center justify-center rounded-full bg-fd-muted/60">
        <LivePill />
      </div>
    </section>
  );
}

function CallToAction({ className }: { className?: string }) {
  return (
    <div className={`flex flex-wrap gap-3 ${className ?? ""}`}>
      <Link
        href="/docs/installation"
        className="rounded-full bg-fd-primary px-6 py-3 font-medium text-fd-primary-foreground transition hover:opacity-90"
      >
        Install Warble
      </Link>
      <a
        href={repoUrl}
        className="inline-flex items-center gap-2 rounded-full border bg-fd-card px-6 py-3 font-medium transition hover:bg-fd-accent"
      >
        <GitHubMark /> View on GitHub
      </a>
    </div>
  );
}

function Section({
  eyebrow,
  title,
  children,
}: {
  eyebrow: string;
  title: string;
  children: ReactNode;
}) {
  return (
    <section className="mx-auto w-full max-w-4xl px-6 py-20">
      <p className="text-center text-sm font-medium text-fd-primary">
        {eyebrow}
      </p>
      <h2 className="mx-auto mt-3 mb-12 max-w-2xl text-center text-3xl font-bold tracking-tight text-balance">
        {title}
      </h2>
      {children}
    </section>
  );
}

function GitHubMark() {
  return (
    <svg
      viewBox="0 0 16 16"
      className="size-4"
      fill="currentColor"
      aria-hidden="true"
    >
      <path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0016 8c0-4.42-3.58-8-8-8z" />
    </svg>
  );
}
