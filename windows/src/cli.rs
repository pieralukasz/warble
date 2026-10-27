//! Command-line helpers, mainly for setup and for an AI agent to check that
//! everything works: `warble.exe doctor`, `warble.exe transcribe file.wav`.

use std::path::Path;
use std::time::Instant;

use crate::config::Config;
use crate::dictionary::Dictionary;
use crate::{app, audio_math, model, recorder, storage, transcriber::Transcriber};

const HELP: &str = "Warble for Windows: hold a key, speak, let go.

Usage:
  warble                       start the app (tray icon)
  warble --hidden              start in the tray without opening the window
  warble doctor                check folders, model, microphones and settings
  warble download-model        download the speech model (about 670 MB)
  warble verify-model          re-check the model files' SHA-256 hashes
  warble transcribe FILE.wav   transcribe a WAV file and print the text
  warble --version

Data:   %APPDATA%\\Warble (config.json, dictionary.json, history.json, warble.log)
Model:  %LOCALAPPDATA%\\io.github.pieralukasz.warble\\models";

/// Returns `Some(exit code)` when the arguments were a CLI command.
pub fn handle(args: &[String]) -> Option<i32> {
    let command = args.first()?.as_str();
    let code = match command {
        "--hidden" => return None,
        "--help" | "-h" | "help" => {
            println!("{HELP}");
            0
        }
        "--version" | "-V" => {
            println!("warble {}", env!("CARGO_PKG_VERSION"));
            0
        }
        "doctor" => doctor(),
        "download-model" => download(),
        "verify-model" => verify(),
        "transcribe" => match args.get(1) {
            Some(file) => transcribe(Path::new(file)),
            None => {
                eprintln!("Usage: warble transcribe FILE.wav");
                2
            }
        },
        other => {
            eprintln!("Unknown command: {other}\n\n{HELP}");
            2
        }
    };
    Some(code)
}

fn doctor() -> i32 {
    let data = storage::data_dir();
    let dir = model::model_dir(&storage::models_dir());
    let (config, warning) = Config::load(&data.join("config.json"));
    let dictionary = Dictionary::load(data.join("dictionary.json"));
    let installed = model::is_installed(&dir);
    println!("warble {}", env!("CARGO_PKG_VERSION"));
    println!("data folder:   {}", data.display());
    println!("model folder:  {}", dir.display());
    println!("model:         {}", if installed { "installed" } else { "MISSING (run: warble download-model)" });
    println!("hotkey:        {} ({} mode)", config.hotkey, if config.toggle_mode { "toggle" } else { "hold" });
    println!("dictionary:    {} entries", dictionary.entries.len());
    let mics = recorder::microphones();
    println!("microphones:   {}", if mics.is_empty() { "NONE FOUND".to_string() } else { mics.join(" | ") });
    if let Some(warning) = warning.or(dictionary.load_warning) {
        println!("warning:       {warning}");
    }
    if installed && !mics.is_empty() { 0 } else { 1 }
}

fn download() -> i32 {
    let dir = model::model_dir(&storage::models_dir());
    println!("Downloading {} MB to {}", model::total_size() / 1_000_000, dir.display());
    let mut last = 0;
    let result = model::download(&dir, |done, total| {
        let percent = done * 100 / total.max(1);
        if percent >= last + 5 || done == total {
            last = percent;
            println!("{percent}%");
        }
    });
    match result {
        Ok(()) => {
            println!("Model ready.");
            0
        }
        Err(err) => {
            eprintln!("{err}");
            1
        }
    }
}

fn verify() -> i32 {
    match model::verify(&model::model_dir(&storage::models_dir())) {
        Ok(()) => {
            println!("All model files match their SHA-256 hashes.");
            0
        }
        Err(err) => {
            eprintln!("{err}");
            1
        }
    }
}

fn transcribe(file: &Path) -> i32 {
    let samples = match read_wav(file) {
        Ok(samples) => samples,
        Err(err) => {
            eprintln!("{err}");
            return 1;
        }
    };
    let dir = model::model_dir(&storage::models_dir());
    if !model::is_installed(&dir) {
        eprintln!("The model is missing. Run: warble download-model");
        return 1;
    }
    let started = Instant::now();
    let transcriber = match Transcriber::load(&dir) {
        Ok(t) => t,
        Err(err) => {
            eprintln!("{err}");
            return 1;
        }
    };
    let loaded = started.elapsed();
    let started = Instant::now();
    match transcriber.transcribe(&samples) {
        Ok(raw) => {
            let data = storage::data_dir();
            let (config, _) = Config::load(&data.join("config.json"));
            let dictionary = Dictionary::load(data.join("dictionary.json"));
            println!("{}", app::clean_up(&raw, &config, &dictionary.entries));
            eprintln!(
                "(model loaded in {:.1}s, {:.1}s of audio transcribed in {:.1}s)",
                loaded.as_secs_f32(),
                samples.len() as f32 / 16_000.0,
                started.elapsed().as_secs_f32()
            );
            0
        }
        Err(err) => {
            eprintln!("{err}");
            1
        }
    }
}

/// Any PCM or float WAV, converted to 16 kHz mono.
fn read_wav(file: &Path) -> Result<Vec<f32>, String> {
    let mut reader = hound::WavReader::open(file).map_err(|e| format!("Cannot read {}: {e}", file.display()))?;
    let spec = reader.spec();
    let samples: Vec<f32> = match spec.sample_format {
        hound::SampleFormat::Float => reader.samples::<f32>().collect::<Result<_, _>>(),
        hound::SampleFormat::Int => {
            let scale = (1i64 << (spec.bits_per_sample - 1)) as f32;
            reader.samples::<i32>().map(|s| s.map(|v| v as f32 / scale)).collect::<Result<_, _>>()
        }
    }
    .map_err(|e| format!("Cannot decode {}: {e}", file.display()))?;
    let mono = audio_math::to_mono(&samples, spec.channels as usize);
    Ok(audio_math::resample_to_16k(&mono, spec.sample_rate))
}
