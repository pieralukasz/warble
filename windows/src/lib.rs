//! Warble for Windows. The platform-neutral parts (text clean-up, dictionary,
//! history, settings, model files) are plain modules with unit tests; `app`
//! wires them into a Tauri tray app.

pub mod app;
pub mod audio_math;
pub mod cli;
pub mod config;
pub mod dictionary;
pub mod history;
pub mod inserter;
pub mod lifecycle;
pub mod logger;
pub mod model;
pub mod platform;
pub mod recorder;
pub mod storage;
pub mod text;
pub mod transcriber;
