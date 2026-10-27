//! A tiny logger: stderr plus `warble.log` in the data folder, so a helper
//! (or an AI agent) can read what happened without a debugger.

use log::{LevelFilter, Log, Metadata, Record};
use std::fs::{File, OpenOptions};
use std::io::Write;
use std::path::Path;
use std::sync::Mutex;

struct Logger {
    file: Option<Mutex<File>>,
}

impl Log for Logger {
    fn enabled(&self, metadata: &Metadata) -> bool {
        let target = metadata.target();
        let ours = target.starts_with("warble") || target.starts_with("transcribe_rs");
        metadata.level() <= log::Level::Warn || (ours && metadata.level() <= log::Level::Info)
    }

    fn log(&self, record: &Record) {
        if !self.enabled(record.metadata()) {
            return;
        }
        let line = format!(
            "{} {:<5} {}\n",
            chrono::Local::now().format("%Y-%m-%d %H:%M:%S"),
            record.level(),
            record.args()
        );
        eprint!("{line}");
        if let Some(file) = &self.file {
            if let Ok(mut file) = file.lock() {
                let _ = file.write_all(line.as_bytes());
            }
        }
    }

    fn flush(&self) {}
}

pub fn init(data_dir: &Path) {
    let _ = std::fs::create_dir_all(data_dir);
    let path = data_dir.join("warble.log");
    // Start over when the log grows past 2 MB.
    if std::fs::metadata(&path).map(|m| m.len() > 2 << 20).unwrap_or(false) {
        let _ = std::fs::rename(&path, data_dir.join("warble.old.log"));
    }
    let file = OpenOptions::new().create(true).append(true).open(path).ok().map(Mutex::new);
    let logger = Box::leak(Box::new(Logger { file }));
    if log::set_logger(logger).is_ok() {
        log::set_max_level(LevelFilter::Info);
    }
}
