//! Audio helpers: down-mix to mono, resample to the 16 kHz Parakeet expects,
//! and measure a level for the pill's meter.

pub const TARGET_RATE: u32 = 16_000;

/// Averages interleaved channels into one.
pub fn to_mono(interleaved: &[f32], channels: usize) -> Vec<f32> {
    if channels <= 1 {
        return interleaved.to_vec();
    }
    interleaved
        .chunks(channels)
        .map(|frame| frame.iter().sum::<f32>() / frame.len() as f32)
        .collect()
}

/// Resamples mono audio to 16 kHz.
///
/// Downsampling averages each output sample's span of input (a box filter),
/// which removes most of the aliasing a plain pick would add; upsampling
/// interpolates linearly. Plenty for speech recognition.
pub fn resample_to_16k(samples: &[f32], rate: u32) -> Vec<f32> {
    if rate == TARGET_RATE || samples.is_empty() {
        return samples.to_vec();
    }
    let ratio = rate as f64 / TARGET_RATE as f64;
    let out_len = ((samples.len() as f64) / ratio).floor() as usize;
    let mut out = Vec::with_capacity(out_len);
    if ratio > 1.0 {
        for i in 0..out_len {
            let start = (i as f64 * ratio).floor() as usize;
            let end = (((i + 1) as f64 * ratio).floor() as usize).clamp(start + 1, samples.len());
            let span = &samples[start..end];
            out.push(span.iter().sum::<f32>() / span.len() as f32);
        }
    } else {
        for i in 0..out_len {
            let pos = i as f64 * ratio;
            let idx = pos.floor() as usize;
            let frac = (pos - idx as f64) as f32;
            let a = samples[idx];
            let b = samples.get(idx + 1).copied().unwrap_or(a);
            out.push(a + (b - a) * frac);
        }
    }
    out
}

/// Root mean square mapped to 0..1 with a gentle curve, for the level meter.
pub fn level(samples: &[f32]) -> f32 {
    if samples.is_empty() {
        return 0.0;
    }
    let rms = (samples.iter().map(|s| s * s).sum::<f32>() / samples.len() as f32).sqrt();
    (rms * 8.0).sqrt().min(1.0)
}

/// True when a recording is too quiet to contain speech.
pub fn is_silent(samples: &[f32]) -> bool {
    samples.iter().all(|s| s.abs() < 0.003)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn mono_averages_channels() {
        assert_eq!(to_mono(&[1.0, 0.0, 0.5, 0.5], 2), vec![0.5, 0.5]);
        assert_eq!(to_mono(&[0.2, 0.4], 1), vec![0.2, 0.4]);
    }

    #[test]
    fn downsampling_keeps_duration_and_tone() {
        let rate = 48_000;
        let tone: Vec<f32> = (0..rate)
            .map(|i| (2.0 * std::f32::consts::PI * 440.0 * i as f32 / rate as f32).sin())
            .collect();
        let out = resample_to_16k(&tone, rate);
        assert_eq!(out.len(), 16_000);
        // A 440 Hz tone keeps nearly all its energy through the box filter.
        let rms = (out.iter().map(|s| s * s).sum::<f32>() / out.len() as f32).sqrt();
        assert!(rms > 0.65 && rms < 0.75, "rms {rms}");
    }

    #[test]
    fn odd_rates_and_upsampling() {
        assert_eq!(resample_to_16k(&vec![0.0; 44_100], 44_100).len(), 16_000);
        let up = resample_to_16k(&[0.0, 1.0, 0.0, 1.0], 8_000);
        assert_eq!(up.len(), 8);
        assert_eq!(up[1], 0.5);
    }

    #[test]
    fn level_and_silence() {
        assert_eq!(level(&[]), 0.0);
        assert!(is_silent(&[0.0, 0.001, -0.002]));
        assert!(!is_silent(&[0.0, 0.2]));
        assert!(level(&[0.5, -0.5]) > 0.9);
    }
}
