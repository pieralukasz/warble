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
import { Screenshot } from "@/components/screenshot";
import { asset, repoUrl } from "@/lib/shared";

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
    text: "NVIDIA’s TDT model runs on Apple’s Neural Engine through FluidAudio. Downloaded once, then fully offline.",
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

const comparison = [
  ["Price", "Free forever", "Monthly subscription"],
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
        <div className="grid gap-4 md:grid-cols-3">
          {steps.map((step, index) => (
            <div key={step.title} className="rounded-2xl border bg-fd-card p-6">
              <div className="mb-4 flex items-center gap-3">
                <span className="flex size-10 items-center justify-center rounded-xl bg-fd-primary/15 text-fd-primary">
                  <step.icon className="size-5" />
                </span>
                <span className="text-sm font-medium text-fd-muted-foreground">
                  Step {index + 1}
                </span>
              </div>
              <h3 className="text-lg font-semibold">{step.title}</h3>
              <p className="mt-1 text-fd-muted-foreground">{step.text}</p>
            </div>
          ))}
        </div>
      </Section>

      <Section
        eyebrow="Features"
        title="Everything a dictation app should do, and nothing it shouldn’t"
      >
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {features.map((feature) => (
            <div
              key={feature.title}
              className="rounded-2xl border bg-fd-card p-6"
            >
              <feature.icon className="mb-4 size-6 text-fd-primary" />
              <h3 className="font-semibold">{feature.title}</h3>
              <p className="mt-1 text-sm text-fd-muted-foreground">
                {feature.text}
              </p>
            </div>
          ))}
        </div>
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
        <div className="grid items-start gap-8 lg:grid-cols-2">
          <ul className="space-y-4">
            {[
              "Audio is recorded only while the key is held and transcribed in memory.",
              "Text, history and your dictionary are plain JSON files in Application Support.",
              "The only network request is the one-time model download from Hugging Face.",
              "No analytics, no crash reporting, no account. Check the source to be sure.",
            ].map((line) => (
              <li key={line} className="flex gap-3">
                <Lock className="mt-0.5 size-5 shrink-0 text-fd-primary" />
                <span>{line}</span>
              </li>
            ))}
          </ul>
          <div className="overflow-hidden rounded-2xl border">
            <table className="w-full text-sm">
              <thead className="bg-fd-muted">
                <tr>
                  <th className="p-3 text-left font-medium" />
                  <th className="p-3 text-left font-semibold text-fd-primary">
                    Warble
                  </th>
                  <th className="p-3 text-left font-medium text-fd-muted-foreground">
                    Typical cloud dictation
                  </th>
                </tr>
              </thead>
              <tbody>
                {comparison.map(([label, warble, cloud]) => (
                  <tr key={label} className="border-t">
                    <td className="p-3 text-fd-muted-foreground">{label}</td>
                    <td className="p-3 font-medium">{warble}</td>
                    <td className="p-3 text-fd-muted-foreground">{cloud}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      </Section>

      <section className="mx-auto w-full max-w-5xl px-6 pb-24">
        <div className="warble-glow rounded-3xl border bg-fd-card px-8 py-14 text-center">
          <h2 className="text-3xl font-bold tracking-tight">
            Start talking to your Mac
          </h2>
          <p className="mx-auto mt-3 max-w-xl text-fd-muted-foreground">
            Build it from source in one command. Setup walks you through
            permissions and the model download.
          </p>
          <CallToAction className="mt-8 justify-center" />
        </div>
      </section>

      <footer className="border-t py-8 text-center text-sm text-fd-muted-foreground">
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
      </footer>
    </main>
  );
}

function Hero() {
  return (
    <section className="warble-glow relative overflow-hidden">
      <div className="mx-auto flex max-w-5xl flex-col items-center px-6 pt-20 pb-12 text-center">
        {/* biome-ignore lint/performance/noImgElement: static export serves plain files */}
        <img
          src={asset("/icon-256.png")}
          alt="Warble icon"
          width={96}
          height={96}
          className="mb-6 drop-shadow-xl"
        />
        <span className="mb-5 rounded-full border bg-fd-card px-3 py-1 text-xs font-medium text-fd-muted-foreground">
          Free · Open source · Runs on your Mac
        </span>
        <h1 className="text-5xl font-bold tracking-tight sm:text-6xl">
          Your voice, <span className="text-fd-primary">typed.</span>
        </h1>
        <p className="mt-5 max-w-2xl text-lg text-fd-muted-foreground">
          Hold a key, speak, let go. Warble turns speech into text in any Mac
          app with NVIDIA Parakeet, without the cloud, the account or the
          subscription.
        </p>
        <CallToAction className="mt-8 justify-center" />
      </div>
      <div className="relative mx-auto max-w-5xl px-6 pb-20">
        <Screenshot
          name="history"
          alt="Warble main window with History grouped by day"
          className="my-0"
        />
        <Screenshot
          name="pill-recording"
          alt="The recording pill with a live waveform"
          bare
          className="absolute -bottom-2 left-1/2 my-0 w-72 -translate-x-1/2 drop-shadow-2xl"
        />
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
    <section className="mx-auto w-full max-w-5xl px-6 py-16">
      <p className="text-sm font-semibold uppercase tracking-wider text-fd-primary">
        {eyebrow}
      </p>
      <h2 className="mt-2 mb-8 text-3xl font-bold tracking-tight">{title}</h2>
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
