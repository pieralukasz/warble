import Link from "next/link";
import { DictationDemo } from "@/components/home/dictation-demo";
import { Reveal } from "@/components/home/reveal";
import { SearchButton } from "@/components/home/search-button";
import { WindowShowcase } from "@/components/home/window-showcase";
import { asset, authorUrl, repoUrl } from "@/lib/shared";

const parts = [
  {
    id: "pill",
    name: "The recording pill",
    line: "One piece of Liquid Glass near the bottom of the screen: waveform, dots, then a check mark.",
  },
  {
    id: "key",
    name: "Your key",
    line: "fn, Right ⌘, F5 or Ctrl+Space. Hold it, or press once to start and once to stop.",
  },
  {
    id: "toggles",
    name: "Quick toggles",
    line: "Language, mode, pill and sounds, one click away in the menu bar.",
  },
  {
    id: "punctuation",
    name: "Spoken punctuation",
    line: "Say “comma”, “period” or “new line” when it is switched on.",
  },
  {
    id: "dictionary",
    name: "Replacements",
    line: "Say “my email” and get the address. Rules run on your Mac after every dictation.",
  },
  {
    id: "setup",
    name: "Setup",
    line: "Permissions, the speech model, your key and language, then a practice run.",
  },
  {
    id: "cli",
    name: "Command line",
    line: "Status, hotkey, language, autostart, and transcribing an audio file.",
  },
  {
    id: "typed",
    name: "Typed",
    line: "The check mark stays for 1.2 seconds, then the pill is gone.",
  },
] as const;

const trip = [
  {
    heading: "While you hold the key",
    rows: [
      ["Recording", "16 kHz mono audio, from your input", "while held"],
      ["A brushed key", "is ignored, nothing is typed", "under 0.25 s"],
    ],
  },
  {
    heading: "After you let go",
    rows: [
      ["Parakeet TDT v3", "transcribes on the Neural Engine", "on your Mac"],
      ["Spoken punctuation", "turns “comma” into a comma", "if switched on"],
      ["Your dictionary", "fixes names, expands shortcuts", "on your Mac"],
      ["The text", "is pasted at the cursor", "in the app in front"],
      ["The pill", "shows a check mark", "for 1.2 s"],
      ["Your clipboard", "is put back as it was", "after 1 s"],
      ["History", "keeps the text and the app’s name", "Application Support"],
    ],
  },
] as const;

const promises = [
  ["No account", "Nothing to sign up for or log in to."],
  ["No subscription", "Free, with no word limit."],
  ["Offline", "After one model download from Hugging Face."],
  ["Mic on, key down", "Audio is recorded only while you hold the key."],
  ["Plain JSON", "History and dictionary in Application Support."],
  ["No analytics", "No crash reporting either."],
] as const;

const comparison = [
  ["Price", "Free", "Subscription, or a capped free plan"],
  ["Word limit", "None", "Weekly cap on free plans"],
  ["Where speech is processed", "On your Mac", "Remote servers"],
  ["Account", "None", "Required"],
  ["Works offline", "Yes", "No"],
  ["Source code", "Open, MIT", "Closed"],
] as const;

const languages = [
  ["EN", "English"],
  ["PL", "Polish"],
  ["DE", "German"],
  ["FR", "French"],
  ["ES", "Spanish"],
  ["IT", "Italian"],
  ["PT", "Portuguese"],
  ["NL", "Dutch"],
  ["SV", "Swedish"],
  ["CS", "Czech"],
] as const;

const footerLinks = [
  {
    title: "Use it",
    links: [
      ["Installation", "/docs/installation"],
      ["Your first dictation", "/docs/first-run"],
      ["Dictating", "/docs/dictating"],
      ["Dictionary", "/docs/dictionary"],
    ],
  },
  {
    title: "Reference",
    links: [
      ["Settings", "/docs/settings"],
      ["Languages", "/docs/languages"],
      ["Command line", "/docs/cli"],
      ["Troubleshooting", "/docs/troubleshooting"],
    ],
  },
  {
    title: "Source",
    links: [
      ["GitHub", repoUrl],
      ["Issues", `${repoUrl}/issues`],
      ["Architecture", "/docs/architecture"],
      ["Contributing", "/docs/contributing"],
    ],
  },
] as const;

const WORDMARK = ["W", "a", "r", "b", "l", "e"] as const;

export default function HomePage() {
  return (
    <main className="wb-main">
      <Nav />
      <Hero />

      <section className="wb-section wb-showcase" aria-label="The app">
        <WindowShowcase />
      </section>

      <Parts />
      <Trip />
      <Promises />
      <ParakeetBand />
      <Languages />
      <Install />
      <Footer />
      <Reveal />
    </main>
  );
}

function Nav() {
  return (
    <header className="wb-nav">
      <Link href="/" className="wb-wordmark">
        {/* biome-ignore lint/performance/noImgElement: static export serves plain files */}
        <img src={asset("/icon-256.png")} alt="" width={32} height={32} />
        Warble
      </Link>
      <nav aria-label="Main" className="wb-nav-links">
        <Link className="wb-link" href="/docs">
          Docs
        </Link>
        <Link className="wb-link" href="/docs/languages">
          Languages
        </Link>
        <Link className="wb-link" href="/docs/privacy">
          Privacy
        </Link>
        <a className="wb-link" href={repoUrl}>
          GitHub
        </a>
        <SearchButton className="wb-link wb-link-button" />
      </nav>
      <Link href="/docs/installation" className="wb-button wb-button-small">
        Install
      </Link>
    </header>
  );
}

function Hero() {
  return (
    <section className="wb-hero">
      <div className="wb-hero-copy">
        <h1 className="wb-hero-title">
          <span className="wb-line">
            <span data-line style={{ "--i": 0 } as React.CSSProperties}>
              Hold a key,
            </span>
          </span>
          <span className="wb-line">
            <span data-line style={{ "--i": 1 } as React.CSSProperties}>
              speak, let go.
            </span>
          </span>
        </h1>
        <p
          className="wb-hero-lead"
          data-rise
          style={{ "--i": 2 } as React.CSSProperties}
        >
          Free dictation for macOS. Warble types what you say into any app, and
          NVIDIA Parakeet transcribes it on your Mac.
        </p>
        <div
          className="wb-actions"
          data-rise
          style={{ "--i": 3 } as React.CSSProperties}
        >
          <Link href="/docs/installation" className="wb-button">
            Install Warble
          </Link>
          <a className="wb-link wb-link-strong" href={repoUrl}>
            Source on GitHub
          </a>
        </div>
      </div>
      <div className="wb-hero-stage">
        <DictationDemo />
      </div>
    </section>
  );
}

function Parts() {
  return (
    <section className="wb-section wb-parts" aria-labelledby="parts-heading">
      <div className="wb-board">
        <div className="wb-tile wb-tile-heading" data-reveal>
          <h2 id="parts-heading">The parts you touch</h2>
        </div>
        {parts.map((part) => (
          <figure
            key={part.id}
            className={`wb-tile wb-tile-${part.id}`}
            data-reveal
          >
            <PartPicture id={part.id} />
            <figcaption>
              <strong>{part.name}</strong>
              <span>{part.line}</span>
            </figcaption>
          </figure>
        ))}
      </div>
    </section>
  );
}

function PartPicture({ id }: { id: (typeof parts)[number]["id"] }) {
  switch (id) {
    case "pill":
      return (
        // biome-ignore lint/performance/noImgElement: static export serves plain files
        <img
          className="wb-crop wb-crop-pill"
          src={asset("/screenshots/pill-recording.png")}
          width={720}
          height={144}
          alt="The recording pill while listening, with a live waveform"
          loading="lazy"
          decoding="async"
        />
      );
    case "typed":
      return (
        // biome-ignore lint/performance/noImgElement: static export serves plain files
        <img
          className="wb-crop wb-crop-typed"
          src={asset("/screenshots/pill-inserted.png")}
          width={720}
          height={144}
          alt="The pill as a small circle with a check mark after the text is typed"
          loading="lazy"
          decoding="async"
        />
      );
    case "setup":
      return (
        // biome-ignore lint/performance/noImgElement: static export serves plain files
        <img
          className="wb-crop wb-crop-setup"
          src={asset("/screenshots/onboarding-4.png")}
          width={1280}
          height={1144}
          alt="Setup step where you pick your key and language"
          loading="lazy"
          decoding="async"
        />
      );
    case "key":
      return (
        <div className="wb-macro wb-macro-key" data-ui aria-hidden="true">
          <span className="wb-cap">fn</span>
        </div>
      );
    case "toggles":
      return (
        <div className="wb-macro wb-macro-toggles" data-ui aria-hidden="true">
          <span className="wb-round">PL</span>
          <span className="wb-round">
            <svg viewBox="0 0 24 24" aria-hidden="true">
              <rect
                x="3"
                y="7"
                width="18"
                height="10"
                rx="5"
                fill="currentColor"
              />
            </svg>
          </span>
        </div>
      );
    case "punctuation":
      return (
        <div className="wb-macro wb-macro-punct" data-ui aria-hidden="true">
          <span>
            comma <b>,</b>
          </span>
        </div>
      );
    case "dictionary":
      return (
        <div className="wb-macro wb-macro-dict" data-ui aria-hidden="true">
          <span className="wb-dict-from">my email</span>
          <span className="wb-dict-arrow">→</span>
          <span className="wb-dict-to">hello@example.com</span>
        </div>
      );
    case "cli":
      return (
        <div className="wb-macro wb-macro-cli" data-ui aria-hidden="true">
          <code>warble set-language pl</code>
        </div>
      );
  }
}

function Trip() {
  return (
    <section
      className="wb-section wb-trip"
      aria-label="What happens between the key and the text"
    >
      {trip.map((part, partIndex) => (
        <div key={part.heading} className="wb-trip-part" data-reveal>
          {partIndex === 0 ? (
            <h2 className="wb-trip-heading">{part.heading}</h2>
          ) : (
            <h3 className="wb-trip-heading">{part.heading}</h3>
          )}
          <table className="wb-trip-table">
            <tbody>
              {part.rows.map(([what, does, when]) => (
                <tr key={what}>
                  <th scope="row">{what}</th>
                  <td>{does}</td>
                  <td>{when}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      ))}
    </section>
  );
}

function Promises() {
  return (
    <section
      className="wb-section wb-promises"
      aria-labelledby="privacy-heading"
    >
      <ul className="wb-capsules">
        <li className="wb-capsule wb-capsule-heading" data-reveal>
          <h2 id="privacy-heading">Nothing leaves your Mac</h2>
        </li>
        {promises.map(([name, line]) => (
          <li key={name} className="wb-capsule" data-reveal>
            <strong>{name}</strong>
            <span>{line}</span>
          </li>
        ))}
      </ul>

      <div className="wb-compare" data-reveal>
        <table className="wb-compare-table">
          <thead>
            <tr>
              <th scope="col">
                <span className="wb-sr">Compared</span>
              </th>
              <th scope="col">Warble</th>
              <th scope="col">Typical cloud dictation</th>
            </tr>
          </thead>
          <tbody>
            {comparison.map(([label, warble, cloud]) => (
              <tr key={label}>
                <th scope="row">{label}</th>
                <td>{warble}</td>
                <td>{cloud}</td>
              </tr>
            ))}
          </tbody>
        </table>
        <p className="wb-compare-note">
          Warble is not the only app that keeps speech on your Mac. Handy,
          VoiceInk, Superwhisper and MacWhisper run local models too. Warble’s
          take is a native macOS 26 app on the Neural Engine, free and MIT
          licensed, that does dictation and nothing else.{" "}
          <Link className="wb-link wb-link-strong" href="/docs/privacy">
            Read the privacy page
          </Link>
        </p>
      </div>
    </section>
  );
}

function ParakeetBand() {
  return (
    <section className="wb-band" aria-labelledby="parakeet-heading">
      <figure className="wb-band-picture" data-reveal>
        <div className="wb-band-mask wb-shutter">
          {/* biome-ignore lint/performance/noImgElement: static export serves plain files */}
          <img
            src={asset("/home/parakeet-jakuchu.webp")}
            width={1428}
            height={1600}
            alt="Woodblock print of a green parakeet on a branch of dark red seed pods under large green leaves, on a black ground"
            loading="lazy"
            decoding="async"
          />
        </div>
        <figcaption>
          “Parakeet”, after a design by Itō Jakuchū, ca. 1900. The Metropolitan
          Museum of Art, public domain.
        </figcaption>
      </figure>
      <div className="wb-band-copy" data-reveal>
        <h2 id="parakeet-heading">The model is called Parakeet</h2>
        <p>
          NVIDIA Parakeet TDT v3 runs on the Neural Engine through FluidAudio.
          It downloads once, about 500 MB, and then works offline.
        </p>
        <p>
          Warble began as a fork of open-wispr by human37, with one narrow goal:
          fast, local dictation in Polish. Its config still carries over on
          first launch.
        </p>
        <p>
          For whole calls and meetings with the speakers told apart, there is{" "}
          <a
            className="wb-link wb-link-strong"
            href="https://github.com/pieralukasz/echopad"
          >
            EchoPad
          </a>
          , built on the same model.
        </p>
      </div>
    </section>
  );
}

function Languages() {
  return (
    <section
      className="wb-section wb-languages"
      aria-labelledby="languages-heading"
    >
      <ul className="wb-words">
        <li className="wb-word wb-word-heading" data-reveal>
          <h2 id="languages-heading">25 languages</h2>
          <span>or Auto-Detect</span>
        </li>
        {languages.map(([code, name]) => (
          <li key={code} className="wb-word" data-reveal>
            <b lang={code.toLowerCase()}>{code}</b>
            <span>{name}</span>
          </li>
        ))}
        <li className="wb-word wb-word-more" data-reveal>
          <Link href="/docs/languages">
            <b>+18</b>
            <span>All 28 codes</span>
          </Link>
        </li>
      </ul>
    </section>
  );
}

function Install() {
  return (
    <section
      className="wb-section wb-install"
      aria-labelledby="install-heading"
    >
      <h2 id="install-heading" className="wb-install-heading">
        Install in one command
      </h2>
      <ol className="wb-grow">
        <li className="wb-grow-stage" data-reveal>
          <div className="wb-grow-tile wb-grow-a">
            <pre>
              <code>
                git clone https://github.com/
                <wbr />
                pieralukasz/warble.git
              </code>
            </pre>
          </div>
          <p className="wb-grow-name">First, clone it</p>
          <p className="wb-grow-line">
            Needs macOS 26 and Xcode 26 or its Command Line Tools (Swift 6.2).
          </p>
        </li>
        <li className="wb-grow-stage" data-reveal>
          <div className="wb-grow-tile wb-grow-b">
            <pre>
              <code>cd warble{"\n"}scripts/install.sh</code>
            </pre>
          </div>
          <p className="wb-grow-name">Then run the script</p>
          <p className="wb-grow-line">
            It builds a release, puts Warble.app in ~/Applications and links the
            warble command.
          </p>
        </li>
        <li className="wb-grow-stage" data-reveal>
          <div className="wb-grow-tile wb-grow-c">
            {/* biome-ignore lint/performance/noImgElement: static export serves plain files */}
            <img
              src={asset("/screenshots/onboarding-0.png")}
              width={1280}
              height={1144}
              alt="Warble’s setup window: Welcome to Warble"
              loading="lazy"
              decoding="async"
            />
          </div>
          <p className="wb-grow-name">Setup does the rest</p>
          <p className="wb-grow-line">
            Microphone and Accessibility, the 500 MB model, your key, a practice
            dictation.
          </p>
        </li>
      </ol>
      <div className="wb-install-after" data-reveal>
        <p>
          Using a coding agent? Point Claude Code or Codex at the repository and
          ask it to follow the{" "}
          <Link
            className="wb-link wb-link-strong"
            href="/docs/installation#for-agents"
          >
            install steps for agents
          </Link>
          . Only the Microphone and Accessibility prompts need you. Coming from
          open-wispr? Warble imports its config on first launch.
        </p>
        <Link href="/docs/installation" className="wb-button">
          Install Warble
        </Link>
      </div>
    </section>
  );
}

function Footer() {
  return (
    <footer className="wb-footer">
      <div className="wb-mark" role="img" aria-label="Warble">
        {WORDMARK.map((letter, index) => (
          <span
            // biome-ignore lint/suspicious/noArrayIndexKey: the letters never reorder
            key={index}
            className="wb-mark-block"
            aria-hidden="true"
            style={{ "--i": index } as React.CSSProperties}
          >
            {letter}
          </span>
        ))}
      </div>
      <div className="wb-footer-grid">
        {footerLinks.map((column) => (
          <div key={column.title} className="wb-footer-col">
            <h2>{column.title}</h2>
            <ul>
              {column.links.map(([label, href]) => (
                <li key={label}>
                  {href.startsWith("http") ? (
                    <a className="wb-link" href={href}>
                      {label}
                    </a>
                  ) : (
                    <Link className="wb-link" href={href}>
                      {label}
                    </Link>
                  )}
                </li>
              ))}
            </ul>
          </div>
        ))}
        <div className="wb-footer-col wb-footer-credits">
          <p>
            Made by{" "}
            <a className="wb-link wb-link-strong" href={authorUrl}>
              Lucas Piera
            </a>
            . Built on{" "}
            <a
              className="wb-link wb-link-strong"
              href="https://github.com/FluidInference/FluidAudio"
            >
              FluidAudio
            </a>{" "}
            and NVIDIA Parakeet, grown from{" "}
            <a
              className="wb-link wb-link-strong"
              href="https://github.com/human37/open-wispr"
            >
              open-wispr
            </a>
            .
          </p>
          <p>
            Picture:{" "}
            <a
              className="wb-link wb-link-strong"
              href="https://www.metmuseum.org/art/collection/search/57121"
            >
              “Parakeet” by Itō Jakuchū
            </a>
            , ca. 1900, public domain (CC0), via The Metropolitan Museum of Art.
          </p>
        </div>
      </div>
      <div className="wb-footer-last">
        <p>Free and open source, MIT licensed.</p>
        <Link href="/docs/installation" className="wb-button wb-button-small">
          Install
        </Link>
      </div>
    </footer>
  );
}
