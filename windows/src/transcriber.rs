//! Speech to text with Parakeet through ONNX Runtime, on the CPU.

use std::path::Path;
use std::sync::Mutex;
use transcribe_rs::onnx::parakeet::{ParakeetModel, ParakeetParams};
use transcribe_rs::onnx::Quantization;

pub struct Transcriber {
    model: Mutex<ParakeetModel>,
}

impl Transcriber {
    pub fn load(dir: &Path) -> Result<Self, String> {
        let model = ParakeetModel::load(dir, &Quantization::Int8)
            .map_err(|e| format!("The speech model could not be loaded: {e}"))?;
        Ok(Self { model: Mutex::new(model) })
    }

    /// Transcribes 16 kHz mono samples. Parakeet v3 detects the language itself.
    pub fn transcribe(&self, samples: &[f32]) -> Result<String, String> {
        let mut model = self.model.lock().map_err(|_| "The speech model crashed earlier. Restart Warble.")?;
        let result = model
            .transcribe_with(samples, &ParakeetParams::default())
            .map_err(|e| format!("Transcription failed: {e}"))?;
        Ok(result.text.trim().to_string())
    }
}
