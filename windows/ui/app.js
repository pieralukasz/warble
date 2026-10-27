// Warble main window. Talks to the Rust side through Tauri's global API.
const { invoke } = window.__TAURI__.core;
const { listen } = window.__TAURI__.event;

const $ = (id) => document.getElementById(id);
let state = null;
let dictKind = "word";

// ------------------------------------------------------------ navigation
function showPage(name) {
  document.querySelectorAll(".nav").forEach((b) => {
    if (b.dataset.page === name) b.setAttribute("aria-current", "page");
    else b.removeAttribute("aria-current");
  });
  document.querySelectorAll(".page").forEach((p) => (p.hidden = p.id !== `page-${name}`));
  if (name === "dictionary") loadDictionary();
  if (name === "history") loadHistory();
  if (name === "settings") loadMicrophones();
}
document.querySelectorAll(".nav").forEach((b) => b.addEventListener("click", () => showPage(b.dataset.page)));

// ------------------------------------------------------------ status
function prettyHotkey(combo) {
  return combo
    .split("+")
    .map((k) => k.replace(/^Key/, "").replace(/^Digit/, "").replace("Backquote", "`"))
    .join(" + ");
}

function mb(bytes) {
  return Math.round(bytes / 1_000_000);
}

function render(s) {
  state = s;
  $("version").textContent = `Version ${s.version}`;
  const key = prettyHotkey(s.config.hotkey);
  $("how-to").textContent = s.config.toggleMode
    ? `Press ${key} to start speaking and press it again when you are done. The text appears where your cursor is, in any program.`
    : `Hold ${key} while you speak and let go when you are done. The text appears where your cursor is, in any program.`;

  const m = s.model;
  const download = $("model-download");
  const progress = $("model-progress");
  download.hidden = true;
  progress.hidden = true;
  if (m.kind === "missing") {
    $("model-text").textContent = `Warble needs NVIDIA Parakeet, a speech model of about ${mb(s.modelSize)} MB. It is downloaded once from Hugging Face; after that everything runs on this computer, without internet.`;
    download.hidden = false;
    download.disabled = false;
  } else if (m.kind === "downloading") {
    const pct = Math.floor((m.done / m.total) * 100);
    $("model-text").textContent = `Downloading: ${mb(m.done)} of ${mb(m.total)} MB (${pct}%).`;
    progress.hidden = false;
    $("model-bar").style.width = `${pct}%`;
  } else if (m.kind === "loading") {
    $("model-text").textContent = "Loading the model. This takes a few seconds.";
  } else if (m.kind === "ready") {
    $("model-text").textContent = "Ready. Dictation works offline.";
  } else if (m.kind === "failed") {
    $("model-text").textContent = `Something went wrong: ${m.message}`;
    download.hidden = false;
    download.disabled = false;
    download.textContent = "Try again";
  }

  if (s.lastText) {
    $("last-text").textContent = s.lastText;
    $("last-text").classList.remove("muted");
    $("last-copy").hidden = false;
  }

  const warnings = [...s.warnings];
  if (s.phase.kind === "error") warnings.push(s.phase.message);
  $("warnings").hidden = warnings.length === 0;
  $("warning-list").replaceChildren(...warnings.map((w) => Object.assign(document.createElement("li"), { textContent: w })));

  renderSettings(s);
}

$("model-download").addEventListener("click", () => {
  $("model-download").disabled = true;
  invoke("start_model_download");
});
$("last-copy").addEventListener("click", async () => {
  await invoke("copy_text", { text: state.lastText });
  flash($("last-copy"), "Copied");
});

function flash(button, text) {
  const old = button.textContent;
  button.textContent = text;
  setTimeout(() => (button.textContent = old), 1200);
}

// ------------------------------------------------------------ dictionary
document.querySelectorAll(".tab").forEach((tab) =>
  tab.addEventListener("click", () => {
    dictKind = tab.dataset.kind;
    document.querySelectorAll(".tab").forEach((t) => t.setAttribute("aria-selected", String(t === tab)));
    const replacement = dictKind === "replacement";
    $("dict-written").hidden = !replacement;
    $("dict-written").required = replacement;
    $("dict-spoken").placeholder = replacement ? "When I say, e.g. my email" : "Word, e.g. GitHub";
    loadDictionary();
  })
);

async function loadDictionary(entries) {
  entries = entries ?? (await invoke("dictionary_list"));
  const shown = entries.filter((e) => e.kind === dictKind);
  $("dict-empty").hidden = shown.length > 0;
  $("dict-list").replaceChildren(
    ...shown.map((e) => {
      const li = document.createElement("li");
      li.className = "item";
      const text = document.createElement("span");
      text.className = "text";
      text.textContent = e.kind === "word" ? e.written : `${e.spoken}  →  ${e.written}`;
      const remove = document.createElement("button");
      remove.textContent = "Remove";
      remove.setAttribute("aria-label", `Remove ${e.spoken}`);
      remove.addEventListener("click", async () => loadDictionary(await invoke("dictionary_remove", { id: e.id })));
      li.append(text, remove);
      return li;
    })
  );
}

$("dict-form").addEventListener("submit", async (event) => {
  event.preventDefault();
  $("dict-error").textContent = "";
  try {
    const entries = await invoke("dictionary_add", {
      kind: dictKind,
      spoken: $("dict-spoken").value,
      written: $("dict-written").value,
    });
    $("dict-spoken").value = "";
    $("dict-written").value = "";
    $("dict-spoken").focus();
    loadDictionary(entries);
  } catch (err) {
    $("dict-error").textContent = String(err);
  }
});

// ------------------------------------------------------------ history
let searchTimer;
$("history-search").addEventListener("input", () => {
  clearTimeout(searchTimer);
  searchTimer = setTimeout(loadHistory, 150);
});

async function loadHistory() {
  const entries = await invoke("history_list", { query: $("history-search").value, limit: 500 });
  $("history-empty").hidden = entries.length > 0;
  $("history-empty").textContent = $("history-search").value ? "Nothing matches the search." : "No dictations yet.";
  const days = new Map();
  for (const e of entries) {
    const day = new Date(e.date).toLocaleDateString(undefined, { weekday: "long", day: "numeric", month: "long" });
    if (!days.has(day)) days.set(day, []);
    days.get(day).push(e);
  }
  const nodes = [];
  for (const [day, list] of days) {
    nodes.push(Object.assign(document.createElement("p"), { className: "day", textContent: day }));
    for (const e of list) nodes.push(historyItem(e));
  }
  $("history-list").replaceChildren(...nodes);
}

function historyItem(e) {
  const div = document.createElement("div");
  div.className = "item";
  const body = document.createElement("div");
  body.className = "text";
  const text = document.createElement("div");
  text.textContent = e.text;
  const meta = document.createElement("div");
  meta.className = "meta";
  const time = new Date(e.date).toLocaleTimeString(undefined, { hour: "2-digit", minute: "2-digit" });
  meta.textContent = [time, e.appName, `${e.durationSeconds.toFixed(1)} s`].filter(Boolean).join(" · ");
  body.append(text, meta);
  const copy = document.createElement("button");
  copy.textContent = "Copy";
  copy.addEventListener("click", async () => {
    await invoke("copy_text", { text: e.text });
    flash(copy, "Copied");
  });
  const remove = document.createElement("button");
  remove.textContent = "Delete";
  remove.setAttribute("aria-label", "Delete this dictation");
  remove.addEventListener("click", async () => {
    await invoke("history_remove", { id: e.id });
    loadHistory();
  });
  div.append(body, copy, remove);
  return div;
}

$("history-clear").addEventListener("click", async () => {
  if (!confirm("Delete every dictation from the history? This cannot be undone.")) return;
  $("history-error").textContent = "";
  try {
    await invoke("history_clear");
    loadHistory();
  } catch (err) {
    $("history-error").textContent = String(err);
  }
});

// ------------------------------------------------------------ settings
function renderSettings(s) {
  if (!capturing) $("hotkey-button").textContent = prettyHotkey(s.config.hotkey);
  document.querySelector(`input[name="mode"][value="${s.config.toggleMode ? "toggle" : "hold"}"]`).checked = true;
  $("show-pill").checked = s.config.showPill;
  $("spoken-punctuation").checked = s.config.spokenPunctuation;
  $("keep-clipboard").checked = s.config.keepOnClipboard;
  $("autostart").checked = s.autostart;
  $("data-dir").textContent = s.dataDir;
  $("models-dir").textContent = s.modelsDir;
  $("microphone").value = s.config.microphone ?? "";
}

async function saveConfig(patch) {
  // Shortcut problems show under the shortcut; anything else at the top.
  const errorBox = $("hotkey" in patch ? "settings-error" : "settings-general-error");
  $("settings-error").textContent = "";
  $("settings-general-error").textContent = "";
  try {
    render(await invoke("set_config", { config: { ...state.config, ...patch } }));
  } catch (err) {
    errorBox.textContent = String(err);
    render(await invoke("get_state"));
  }
}

document.querySelectorAll('input[name="mode"]').forEach((r) =>
  r.addEventListener("change", () => saveConfig({ toggleMode: r.value === "toggle" }))
);
$("show-pill").addEventListener("change", (e) => saveConfig({ showPill: e.target.checked }));
$("spoken-punctuation").addEventListener("change", (e) => saveConfig({ spokenPunctuation: e.target.checked }));
$("keep-clipboard").addEventListener("change", (e) => saveConfig({ keepOnClipboard: e.target.checked }));
$("microphone").addEventListener("change", (e) => saveConfig({ microphone: e.target.value || null }));
$("autostart").addEventListener("change", async (e) => {
  $("settings-general-error").textContent = "";
  try {
    e.target.checked = await invoke("set_autostart", { enabled: e.target.checked });
  } catch (err) {
    $("settings-general-error").textContent = String(err);
    e.target.checked = !e.target.checked;
  }
});

async function loadMicrophones() {
  const names = await invoke("list_microphones");
  const options = [new Option("Windows default", "")].concat(names.map((n) => new Option(n, n)));
  $("microphone").replaceChildren(...options);
  $("microphone").value = state?.config.microphone ?? "";
}

// Shortcut capture: click the button, press the new combination, Escape cancels.
let capturing = false;
const MODIFIERS = { Control: "Ctrl", Shift: "Shift", Alt: "Alt", Meta: "Super" };

function stopCapture() {
  capturing = false;
  $("hotkey-button").classList.remove("listening");
  invoke("pause_hotkey", { paused: false });
  if (state) $("hotkey-button").textContent = prettyHotkey(state.config.hotkey);
}

$("hotkey-button").addEventListener("click", () => {
  if (capturing) return stopCapture();
  capturing = true;
  $("settings-error").textContent = "";
  invoke("pause_hotkey", { paused: true });
  $("hotkey-button").classList.add("listening");
  $("hotkey-button").textContent = "Press the new shortcut…";
});

window.addEventListener("keydown", (e) => {
  if (!capturing) return;
  e.preventDefault();
  if (e.key === "Escape") return stopCapture();
  if (MODIFIERS[e.key]) return;
  const parts = [];
  if (e.ctrlKey) parts.push("Ctrl");
  if (e.altKey) parts.push("Alt");
  if (e.shiftKey) parts.push("Shift");
  if (e.metaKey) parts.push("Super");
  const isFunctionKey = /^F\d+$/.test(e.code);
  if (parts.length === 0 && !isFunctionKey) {
    $("hotkey-button").textContent = "Add Ctrl, Alt or Shift (or use F1–F24)";
    return;
  }
  parts.push(e.code);
  stopCapture();
  saveConfig({ hotkey: parts.join("+") });
});
$("hotkey-button").addEventListener("blur", () => capturing && stopCapture());

// ------------------------------------------------------------ start
listen("status", (event) => render(event.payload));
invoke("get_state").then(render);
