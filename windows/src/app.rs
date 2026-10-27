//! The Tauri app: tray icon, hotkey, recording pill and the main window.

use serde::Serialize;
use std::str::FromStr;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex, RwLock};
use std::thread;
use std::time::{Duration, Instant};

use chrono::Utc;
use tauri::menu::{Menu, MenuItem, PredefinedMenuItem};
use tauri::tray::{MouseButton, MouseButtonState, TrayIconBuilder, TrayIconEvent};
use tauri::{AppHandle, Emitter, LogicalSize, Manager, PhysicalPosition, State, WebviewWindow, WindowEvent};
use tauri_plugin_autostart::ManagerExt as _;
use tauri_plugin_global_shortcut::{GlobalShortcutExt, Shortcut, ShortcutState};
use uuid::Uuid;

use crate::config::Config;
use crate::dictionary::{Dictionary, DictionaryEntry, Kind};
use crate::history::{History, HistoryEntry};
use crate::lifecycle::{Action, Lifecycle};
use crate::recorder::{self, Recorder};
use crate::transcriber::Transcriber;
use crate::{audio_math, inserter, model, platform, storage, text};

/// Pressing and releasing faster than this is almost always an accidental tap.
const MINIMUM_RECORDING: Duration = Duration::from_millis(250);
const CONFIRMATION: Duration = Duration::from_millis(1200);
const ERROR_DISPLAY: Duration = Duration::from_secs(5);
const PILL_WIDTH: f64 = 230.0;
const PILL_HEIGHT: f64 = 56.0;

#[derive(Debug, Clone, Serialize, PartialEq)]
#[serde(tag = "kind", rename_all = "camelCase")]
pub enum ModelStatus {
    Missing,
    Downloading { done: u64, total: u64 },
    Loading,
    Ready,
    Failed { message: String },
}

#[derive(Debug, Clone, Serialize, PartialEq)]
#[serde(tag = "kind", rename_all = "camelCase")]
pub enum Phase {
    Idle,
    Recording,
    Transcribing,
    Inserted,
    Error { message: String },
}

struct Session {
    started: Instant,
    app: Option<(String, String)>,
}

pub struct Warble {
    config: Mutex<Config>,
    dictionary: Mutex<Dictionary>,
    history: Mutex<History>,
    lifecycle: Mutex<Lifecycle>,
    recorder: Recorder,
    transcriber: RwLock<Option<Arc<Transcriber>>>,
    model_status: Mutex<ModelStatus>,
    phase: Mutex<(Phase, u64)>,
    session: Mutex<Option<Session>>,
    last_text: Mutex<Option<String>>,
    warnings: Mutex<Vec<String>>,
    hotkey_paused: AtomicBool,
}

#[derive(Clone, Serialize)]
#[serde(rename_all = "camelCase")]
struct Snapshot {
    version: &'static str,
    config: Config,
    model: ModelStatus,
    model_size: u64,
    phase: Phase,
    last_text: Option<String>,
    warnings: Vec<String>,
    data_dir: String,
    models_dir: String,
    autostart: bool,
}

impl Warble {
    fn new() -> Self {
        let dir = storage::data_dir();
        let (config, config_warning) = Config::load(&dir.join("config.json"));
        let dictionary = Dictionary::load(dir.join("dictionary.json"));
        let history = History::load(dir.join("history.json"));
        let warnings = [config_warning, dictionary.load_warning.clone(), history.load_warning.clone()]
            .into_iter()
            .flatten()
            .collect();
        Self {
            config: Mutex::new(config),
            dictionary: Mutex::new(dictionary),
            history: Mutex::new(history),
            lifecycle: Mutex::new(Lifecycle::default()),
            recorder: Recorder::spawn(),
            transcriber: RwLock::new(None),
            model_status: Mutex::new(ModelStatus::Missing),
            phase: Mutex::new((Phase::Idle, 0)),
            session: Mutex::new(None),
            last_text: Mutex::new(None),
            warnings: Mutex::new(warnings),
            hotkey_paused: AtomicBool::new(false),
        }
    }

    fn snapshot(&self, app: &AppHandle) -> Snapshot {
        Snapshot {
            version: env!("CARGO_PKG_VERSION"),
            config: self.config.lock().unwrap().clone(),
            model: self.model_status.lock().unwrap().clone(),
            model_size: model::total_size(),
            phase: self.phase.lock().unwrap().0.clone(),
            last_text: self.last_text.lock().unwrap().clone(),
            warnings: self.warnings.lock().unwrap().clone(),
            data_dir: storage::data_dir().display().to_string(),
            models_dir: model::model_dir(&storage::models_dir()).display().to_string(),
            autostart: app.autolaunch().is_enabled().unwrap_or(false),
        }
    }
}

fn warble(app: &AppHandle) -> State<'_, Warble> {
    app.state::<Warble>()
}

fn broadcast(app: &AppHandle) {
    let snapshot = warble(app).snapshot(app);
    let _ = app.emit("status", snapshot);
}

// ---------------------------------------------------------------- phases & pill

/// Moves to a phase, updates the pill, and optionally returns to idle later.
fn set_phase(app: &AppHandle, phase: Phase, reset_after: Option<Duration>) {
    let generation = {
        let state = warble(app);
        let mut current = state.phase.lock().unwrap();
        current.0 = phase.clone();
        current.1 += 1;
        current.1
    };
    update_pill(app, &phase);
    broadcast(app);
    if let Some(delay) = reset_after {
        let app = app.clone();
        thread::spawn(move || {
            thread::sleep(delay);
            let still_current = warble(&app).phase.lock().unwrap().1 == generation;
            if still_current {
                set_phase(&app, Phase::Idle, None);
            }
        });
    }
}

fn update_pill(app: &AppHandle, phase: &Phase) {
    let Some(pill) = app.get_webview_window("pill") else { return };
    let show = warble(app).config.lock().unwrap().show_pill && *phase != Phase::Idle;
    let _ = app.emit_to("pill", "phase", phase.clone());
    if show {
        place_pill(app, &pill);
        let _ = pill.show();
    } else {
        let _ = pill.hide();
    }
}

/// Bottom centre of the screen the mouse is on, just above the taskbar.
fn place_pill(app: &AppHandle, pill: &WebviewWindow) {
    let monitor = app
        .cursor_position()
        .ok()
        .and_then(|p| app.monitor_from_point(p.x, p.y).ok().flatten())
        .or_else(|| app.primary_monitor().ok().flatten());
    let Some(monitor) = monitor else { return };
    let scale = monitor.scale_factor();
    let area = monitor.work_area();
    let width = (PILL_WIDTH * scale) as i32;
    let height = (PILL_HEIGHT * scale) as i32;
    let x = area.position.x + (area.size.width as i32 - width) / 2;
    let y = area.position.y + area.size.height as i32 - height - (24.0 * scale) as i32;
    let _ = pill.set_size(LogicalSize::new(PILL_WIDTH, PILL_HEIGHT));
    let _ = pill.set_position(PhysicalPosition::new(x, y));
}

fn spawn_level_meter(app: AppHandle) {
    thread::spawn(move || loop {
        if warble(&app).phase.lock().unwrap().0 != Phase::Recording {
            break;
        }
        let level = warble(&app).recorder.level();
        let _ = app.emit_to("pill", "level", level);
        thread::sleep(Duration::from_millis(50));
    });
}

// ---------------------------------------------------------------- dictation

fn on_hotkey(app: &AppHandle, pressed: bool) {
    let state = warble(app);
    if state.hotkey_paused.load(Ordering::Relaxed) {
        return;
    }
    let toggle = state.config.lock().unwrap().toggle_mode;
    let action = {
        let mut lifecycle = state.lifecycle.lock().unwrap();
        if pressed {
            lifecycle.key_down(toggle)
        } else {
            lifecycle.key_up(toggle)
        }
    };
    match action {
        Action::Start => start_recording(app),
        Action::Stop => stop_recording(app),
        Action::None => {}
    }
}

fn start_recording(app: &AppHandle) {
    let state = warble(app);
    let busy = matches!(state.phase.lock().unwrap().0, Phase::Transcribing);
    if busy {
        state.lifecycle.lock().unwrap().start_failed();
        return;
    }
    if state.transcriber.read().unwrap().is_none() {
        state.lifecycle.lock().unwrap().start_failed();
        let message = match &*state.model_status.lock().unwrap() {
            ModelStatus::Loading => "The speech model is still loading. Try again in a moment.",
            ModelStatus::Downloading { .. } => "The speech model is still downloading.",
            _ => "Download the speech model first (open Warble from the tray).",
        };
        set_phase(app, Phase::Error { message: message.into() }, Some(ERROR_DISPLAY));
        show_main(app);
        return;
    }
    *state.session.lock().unwrap() = Some(Session { started: Instant::now(), app: platform::foreground_app() });
    let microphone = state.config.lock().unwrap().microphone.clone();
    match state.recorder.start(microphone) {
        Ok(()) => {
            set_phase(app, Phase::Recording, None);
            spawn_level_meter(app.clone());
        }
        Err(message) => {
            log::error!("warble: recording failed to start: {message}");
            state.lifecycle.lock().unwrap().start_failed();
            *state.session.lock().unwrap() = None;
            set_phase(app, Phase::Error { message }, Some(ERROR_DISPLAY));
        }
    }
}

fn stop_recording(app: &AppHandle) {
    let state = warble(app);
    let Some(session) = state.session.lock().unwrap().take() else { return };
    set_phase(app, Phase::Transcribing, None);
    let app = app.clone();
    thread::spawn(move || {
        let state = warble(&app);
        let samples = state.recorder.stop();
        let duration = session.started.elapsed();
        if duration < MINIMUM_RECORDING {
            set_phase(&app, Phase::Idle, None);
            return;
        }
        if audio_math::is_silent(&samples) {
            let message = "The microphone heard nothing. Check the microphone in Settings.".to_string();
            set_phase(&app, Phase::Error { message }, Some(ERROR_DISPLAY));
            return;
        }
        let Some(transcriber) = state.transcriber.read().unwrap().clone() else { return };
        let raw = match transcriber.transcribe(&samples) {
            Ok(raw) => raw,
            Err(message) => {
                log::error!("warble: {message}");
                set_phase(&app, Phase::Error { message }, Some(ERROR_DISPLAY));
                return;
            }
        };
        let config = state.config.lock().unwrap().clone();
        let text = clean_up(&raw, &config, &state.dictionary.lock().unwrap().entries);
        if text.is_empty() {
            let message = "No speech recognised. Speak a little longer or closer.".to_string();
            set_phase(&app, Phase::Error { message }, Some(ERROR_DISPLAY));
            return;
        }
        if let Err(message) = inserter::insert(&text, config.keep_on_clipboard) {
            log::error!("warble: {message}");
            set_phase(&app, Phase::Error { message }, Some(ERROR_DISPLAY));
        } else {
            set_phase(&app, Phase::Inserted, Some(CONFIRMATION));
        }
        let entry = HistoryEntry {
            id: Uuid::new_v4(),
            date: Utc::now() - chrono::Duration::from_std(duration).unwrap_or_default(),
            text: text.clone(),
            duration_seconds: duration.as_secs_f64(),
            audio_file_name: None,
            app_name: session.app.as_ref().map(|a| a.0.clone()),
            app_bundle_id: session.app.as_ref().map(|a| a.1.clone()),
        };
        if let Err(message) = state.history.lock().unwrap().add(entry) {
            log::error!("warble: {message}");
        }
        *state.last_text.lock().unwrap() = Some(text);
        broadcast(&app);
    });
}

/// Spoken punctuation (when enabled), then the user's dictionary.
pub fn clean_up(raw: &str, config: &Config, entries: &[DictionaryEntry]) -> String {
    let punctuated = if config.spoken_punctuation { text::spoken_punctuation(raw) } else { raw.to_string() };
    text::apply_dictionary(entries, &punctuated).trim().to_string()
}

// ---------------------------------------------------------------- model

fn load_model(app: AppHandle) {
    thread::spawn(move || {
        let dir = model::model_dir(&storage::models_dir());
        if !model::is_installed(&dir) {
            *warble(&app).model_status.lock().unwrap() = ModelStatus::Missing;
            broadcast(&app);
            show_main(&app);
            return;
        }
        *warble(&app).model_status.lock().unwrap() = ModelStatus::Loading;
        broadcast(&app);
        let started = Instant::now();
        let status = match Transcriber::load(&dir) {
            Ok(transcriber) => {
                // A short warm-up so the first real dictation is not the slow one.
                let _ = transcriber.transcribe(&vec![0.0; 16_000]);
                *warble(&app).transcriber.write().unwrap() = Some(Arc::new(transcriber));
                log::info!("warble: model ready in {:.1}s", started.elapsed().as_secs_f32());
                ModelStatus::Ready
            }
            Err(message) => {
                log::error!("warble: {message}");
                ModelStatus::Failed { message }
            }
        };
        *warble(&app).model_status.lock().unwrap() = status;
        broadcast(&app);
    });
}

fn download_model(app: AppHandle) {
    {
        let state = warble(&app);
        let mut status = state.model_status.lock().unwrap();
        if matches!(*status, ModelStatus::Downloading { .. } | ModelStatus::Loading | ModelStatus::Ready) {
            return;
        }
        *status = ModelStatus::Downloading { done: 0, total: model::total_size() };
    }
    broadcast(&app);
    thread::spawn(move || {
        let dir = model::model_dir(&storage::models_dir());
        let result = model::download(&dir, |done, total| {
            *warble(&app).model_status.lock().unwrap() = ModelStatus::Downloading { done, total };
            broadcast(&app);
        });
        match result {
            Ok(()) => load_model(app),
            Err(message) => {
                log::error!("warble: {message}");
                *warble(&app).model_status.lock().unwrap() = ModelStatus::Failed { message };
                broadcast(&app);
            }
        }
    });
}

// ---------------------------------------------------------------- hotkey

/// "Ctrl+Alt+KeyD" as people write it: "Ctrl + Alt + D".
fn pretty_hotkey(combo: &str) -> String {
    combo
        .split('+')
        .map(|k| k.strip_prefix("Key").or_else(|| k.strip_prefix("Digit")).unwrap_or(k))
        .collect::<Vec<_>>()
        .join(" + ")
}

fn register_hotkey(app: &AppHandle, combo: &str) -> Result<(), String> {
    let pretty = pretty_hotkey(combo);
    let shortcut = Shortcut::from_str(combo).map_err(|e| format!("{pretty} is not a valid shortcut: {e}"))?;
    let manager = app.global_shortcut();
    let _ = manager.unregister_all();
    manager
        .on_shortcut(shortcut, |app, _shortcut, event| {
            on_hotkey(app, event.state() == ShortcutState::Pressed);
        })
        .map_err(|e| format!("{pretty} is taken by another program or by Windows. Pick another one. ({e})"))
}

// ---------------------------------------------------------------- windows & tray

fn show_main(app: &AppHandle) {
    if let Some(window) = app.get_webview_window("main") {
        let _ = window.unminimize();
        let _ = window.show();
        let _ = window.set_focus();
    }
}

fn build_tray(app: &AppHandle) -> tauri::Result<()> {
    let open = MenuItem::with_id(app, "open", "Open Warble", true, None::<&str>)?;
    let quit = MenuItem::with_id(app, "quit", "Quit Warble", true, None::<&str>)?;
    let separator = PredefinedMenuItem::separator(app)?;
    let menu = Menu::with_items(app, &[&open, &separator, &quit])?;
    let mut tray = TrayIconBuilder::with_id("warble")
        .tooltip("Warble")
        .menu(&menu)
        .show_menu_on_left_click(false)
        .on_menu_event(|app, event| match event.id.as_ref() {
            "open" => show_main(app),
            "quit" => app.exit(0),
            _ => {}
        })
        .on_tray_icon_event(|tray, event| {
            if let TrayIconEvent::Click { button: MouseButton::Left, button_state: MouseButtonState::Up, .. } = event {
                show_main(tray.app_handle());
            }
        });
    if let Some(icon) = app.default_window_icon() {
        tray = tray.icon(icon.clone());
    }
    tray.build(app)?;
    Ok(())
}

// ---------------------------------------------------------------- commands

#[tauri::command]
fn get_state(app: AppHandle, state: State<'_, Warble>) -> Snapshot {
    state.snapshot(&app)
}

#[tauri::command]
fn set_config(app: AppHandle, state: State<'_, Warble>, config: Config) -> Result<Snapshot, String> {
    let previous = state.config.lock().unwrap().clone();
    if config.hotkey != previous.hotkey {
        if let Err(err) = register_hotkey(&app, &config.hotkey) {
            let _ = register_hotkey(&app, &previous.hotkey);
            return Err(err);
        }
    }
    config.save(&storage::data_dir().join("config.json"))?;
    *state.config.lock().unwrap() = config;
    broadcast(&app);
    Ok(state.snapshot(&app))
}

#[tauri::command]
fn pause_hotkey(state: State<'_, Warble>, paused: bool) {
    state.hotkey_paused.store(paused, Ordering::Relaxed);
}

#[tauri::command]
fn set_autostart(app: AppHandle, enabled: bool) -> Result<bool, String> {
    let launcher = app.autolaunch();
    let result = if enabled { launcher.enable() } else { launcher.disable() };
    result.map_err(|e| format!("Could not change start with Windows: {e}"))?;
    launcher.is_enabled().map_err(|e| e.to_string())
}

#[tauri::command]
fn start_model_download(app: AppHandle) {
    download_model(app);
}

#[tauri::command]
fn list_microphones() -> Vec<String> {
    recorder::microphones()
}

#[tauri::command]
fn dictionary_list(state: State<'_, Warble>) -> Vec<DictionaryEntry> {
    state.dictionary.lock().unwrap().entries.clone()
}

#[tauri::command]
fn dictionary_add(state: State<'_, Warble>, kind: Kind, spoken: String, written: String) -> Result<Vec<DictionaryEntry>, String> {
    let mut dictionary = state.dictionary.lock().unwrap();
    dictionary.add(kind, &spoken, &written)?;
    Ok(dictionary.entries.clone())
}

#[tauri::command]
fn dictionary_remove(state: State<'_, Warble>, id: Uuid) -> Result<Vec<DictionaryEntry>, String> {
    let mut dictionary = state.dictionary.lock().unwrap();
    dictionary.remove(id)?;
    Ok(dictionary.entries.clone())
}

#[tauri::command]
fn history_list(state: State<'_, Warble>, query: String, limit: usize) -> Vec<HistoryEntry> {
    state.history.lock().unwrap().search(&query, limit)
}

#[tauri::command]
fn history_remove(state: State<'_, Warble>, id: Uuid) -> Result<(), String> {
    state.history.lock().unwrap().remove(id)
}

#[tauri::command]
fn history_clear(state: State<'_, Warble>) -> Result<(), String> {
    state.history.lock().unwrap().clear()
}

#[tauri::command]
fn copy_text(text: String) -> Result<(), String> {
    inserter::copy(&text)
}

// ---------------------------------------------------------------- run

pub fn run(start_hidden: bool) {
    tauri::Builder::default()
        .plugin(tauri_plugin_single_instance::init(|app, _args, _cwd| show_main(app)))
        .plugin(tauri_plugin_global_shortcut::Builder::new().build())
        .plugin(tauri_plugin_autostart::init(
            tauri_plugin_autostart::MacosLauncher::LaunchAgent,
            Some(vec!["--hidden"]),
        ))
        .manage(Warble::new())
        .invoke_handler(tauri::generate_handler![
            get_state,
            set_config,
            pause_hotkey,
            set_autostart,
            start_model_download,
            list_microphones,
            dictionary_list,
            dictionary_add,
            dictionary_remove,
            history_list,
            history_remove,
            history_clear,
            copy_text,
        ])
        .setup(move |app| {
            let handle = app.handle().clone();
            build_tray(&handle)?;
            if let Some(pill) = app.get_webview_window("pill") {
                let _ = pill.set_ignore_cursor_events(true);
                let _ = pill.set_focusable(false);
            }
            let hotkey = warble(&handle).config.lock().unwrap().hotkey.clone();
            if let Err(message) = register_hotkey(&handle, &hotkey) {
                log::error!("warble: {message}");
                warble(&handle).warnings.lock().unwrap().push(message);
            }
            if !start_hidden {
                show_main(&handle);
            }
            load_model(handle);
            Ok(())
        })
        .on_window_event(|window, event| {
            // Closing the window keeps Warble running in the tray.
            if let WindowEvent::CloseRequested { api, .. } = event {
                if window.label() == "main" {
                    api.prevent_close();
                    let _ = window.hide();
                }
            }
        })
        .run(tauri::generate_context!())
        .expect("Warble failed to start");
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn hotkeys_read_like_people_write_them() {
        assert_eq!(pretty_hotkey("Ctrl+Alt+KeyD"), "Ctrl + Alt + D");
        assert_eq!(pretty_hotkey("Shift+Digit1"), "Shift + 1");
        assert_eq!(pretty_hotkey("Ctrl+Shift+Space"), "Ctrl + Shift + Space");
    }

    #[test]
    fn clean_up_applies_punctuation_only_when_enabled() {
        let entries = [DictionaryEntry::word("GitHub")];
        let mut config = Config::default();
        assert_eq!(clean_up(" push to github period ", &config, &entries), "push to GitHub period");
        config.spoken_punctuation = true;
        assert_eq!(clean_up("push to github period", &config, &entries), "push to GitHub.");
    }
}
