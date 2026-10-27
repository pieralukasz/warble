// No console window when started from the Start menu or at login.
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use warble_win::{app, cli, logger, platform, storage};

fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();
    if !args.is_empty() {
        platform::attach_parent_console();
    }
    if let Some(code) = cli::handle(&args) {
        std::process::exit(code);
    }
    logger::init(&storage::data_dir());
    log::info!("warble: starting {}", env!("CARGO_PKG_VERSION"));
    app::run(args.iter().any(|a| a == "--hidden"));
}
