//! Microphone capture on a dedicated thread (a cpal stream must stay on the
//! thread that created it on Windows).

use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use cpal::{SampleFormat, Stream};
use std::sync::atomic::{AtomicU32, Ordering};
use std::sync::mpsc::{self, Receiver, Sender};
use std::sync::{Arc, Mutex};
use std::thread;

use crate::audio_math;

enum Command {
    Start(Option<String>, Sender<Result<(), String>>),
    Stop(Sender<Vec<f32>>),
}

/// Handle to the capture thread. Cheap to clone.
#[derive(Clone)]
pub struct Recorder {
    tx: Sender<Command>,
    level: Arc<AtomicU32>,
}

impl Recorder {
    pub fn spawn() -> Self {
        let (tx, rx) = mpsc::channel();
        let level = Arc::new(AtomicU32::new(0));
        let thread_level = level.clone();
        thread::Builder::new()
            .name("warble-recorder".into())
            .spawn(move || run(rx, thread_level))
            .expect("recorder thread");
        Self { tx, level }
    }

    /// Starts capturing from the named microphone, or the default one.
    pub fn start(&self, microphone: Option<String>) -> Result<(), String> {
        let (reply, answer) = mpsc::channel();
        self.tx
            .send(Command::Start(microphone, reply))
            .map_err(|_| "The recorder stopped working. Restart Warble.".to_string())?;
        answer.recv().unwrap_or_else(|_| Err("The recorder stopped working.".into()))
    }

    /// Stops and returns the recording as 16 kHz mono samples.
    pub fn stop(&self) -> Vec<f32> {
        let (reply, answer) = mpsc::channel();
        if self.tx.send(Command::Stop(reply)).is_err() {
            return Vec::new();
        }
        answer.recv().unwrap_or_default()
    }

    /// Latest input level, 0..1, for the pill's meter.
    pub fn level(&self) -> f32 {
        f32::from_bits(self.level.load(Ordering::Relaxed))
    }
}

struct Active {
    _stream: Stream,
    buffer: Arc<Mutex<Vec<f32>>>,
    rate: u32,
}

fn run(rx: Receiver<Command>, level: Arc<AtomicU32>) {
    let mut active: Option<Active> = None;
    for command in rx {
        match command {
            Command::Start(microphone, reply) => {
                // Close any stream still open before opening a new one.
                drop(active.take());
                let result = open(microphone.as_deref(), level.clone());
                let _ = reply.send(result.as_ref().map(|_| ()).map_err(Clone::clone));
                active = result.ok();
            }
            Command::Stop(reply) => {
                let samples = match active.take() {
                    Some(capture) => {
                        let rate = capture.rate;
                        let buffer = std::mem::take(&mut *capture.buffer.lock().unwrap());
                        drop(capture);
                        audio_math::resample_to_16k(&buffer, rate)
                    }
                    None => Vec::new(),
                };
                level.store(0f32.to_bits(), Ordering::Relaxed);
                let _ = reply.send(samples);
            }
        }
    }
}

/// Names of the input devices Windows reports, for the settings page.
pub fn microphones() -> Vec<String> {
    let host = cpal::default_host();
    host.input_devices()
        .map(|devices| devices.filter_map(|d| d.name().ok()).collect())
        .unwrap_or_default()
}

fn open(microphone: Option<&str>, level: Arc<AtomicU32>) -> Result<Active, String> {
    let host = cpal::default_host();
    let device = match microphone {
        Some(name) => host
            .input_devices()
            .map_err(|e| e.to_string())?
            .find(|d| d.name().map(|n| n == name).unwrap_or(false))
            .or_else(|| host.default_input_device()),
        None => host.default_input_device(),
    }
    .ok_or("No microphone found. Plug one in or pick it in Windows sound settings.")?;

    let config = device
        .default_input_config()
        .map_err(|e| format!("The microphone cannot be opened: {e}"))?;
    let rate = config.sample_rate().0;
    let channels = config.channels() as usize;
    let format = config.sample_format();
    let stream_config: cpal::StreamConfig = config.into();
    let buffer = Arc::new(Mutex::new(Vec::<f32>::with_capacity(rate as usize * 30)));

    let sink = {
        let buffer = buffer.clone();
        move |mono: Vec<f32>| {
            level.store(audio_math::level(&mono).to_bits(), Ordering::Relaxed);
            buffer.lock().unwrap().extend_from_slice(&mono);
        }
    };
    let on_error = |err| log::error!("Microphone stream error: {err}");

    let stream = match format {
        SampleFormat::F32 => device.build_input_stream(
            &stream_config,
            move |data: &[f32], _| sink(audio_math::to_mono(data, channels)),
            on_error,
            None,
        ),
        SampleFormat::I16 => device.build_input_stream(
            &stream_config,
            move |data: &[i16], _| {
                let floats: Vec<f32> = data.iter().map(|s| *s as f32 / i16::MAX as f32).collect();
                sink(audio_math::to_mono(&floats, channels))
            },
            on_error,
            None,
        ),
        SampleFormat::U16 => device.build_input_stream(
            &stream_config,
            move |data: &[u16], _| {
                let floats: Vec<f32> = data.iter().map(|s| (*s as f32 - 32768.0) / 32768.0).collect();
                sink(audio_math::to_mono(&floats, channels))
            },
            on_error,
            None,
        ),
        other => return Err(format!("Unsupported microphone sample format: {other:?}")),
    }
    .map_err(|e| format!("The microphone cannot be opened: {e}"))?;

    stream.play().map_err(|e| format!("The microphone cannot start: {e}"))?;
    log::info!("Recording from {:?} at {rate} Hz, {channels} ch", device.name().ok());
    Ok(Active { _stream: stream, buffer, rate })
}
