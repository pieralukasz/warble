// The recording pill: listens to phase and level events from the Rust side.
const { listen } = window.__TAURI__.event;

const BAR_COUNT = 14;
const bars = document.getElementById("bars");
const dots = document.getElementById("dots");
const msg = document.getElementById("msg");
const history = new Array(BAR_COUNT).fill(0);
for (let i = 0; i < BAR_COUNT; i++) bars.appendChild(document.createElement("span"));

function show(phase) {
  bars.hidden = phase.kind !== "recording";
  dots.hidden = phase.kind !== "transcribing";
  msg.classList.toggle("error", phase.kind === "error");
  msg.textContent =
    phase.kind === "recording" ? "Listening" :
    phase.kind === "transcribing" ? "" :
    phase.kind === "inserted" ? "✓ Typed" :
    phase.kind === "error" ? phase.message : "";
  msg.title = msg.textContent;
  if (phase.kind === "recording") history.fill(0);
}

listen("phase", (event) => show(event.payload));
listen("level", (event) => {
  history.shift();
  history.push(event.payload);
  bars.childNodes.forEach((bar, i) => (bar.style.height = `${4 + Math.round(history[i] * 16)}px`));
});
