import AVFoundation

/// Converts raw microphone samples into the 0...1 loudness the waveform draws.
public enum AudioLevel {
    /// Quietest level that still moves the bars; anything below reads as silence.
    static let FLOOR_DECIBELS: Float = -50

    public static func rms(of samples: UnsafeBufferPointer<Float>) -> Float {
        guard !samples.isEmpty else { return 0 }
        let sumOfSquares = samples.reduce(Float(0)) { $0 + $1 * $1 }
        return (sumOfSquares / Float(samples.count)).squareRoot()
    }

    public static func normalized(rms: Float) -> Float {
        guard rms > 0 else { return 0 }
        let decibels = 20 * log10(rms)
        let scaled = (decibels - FLOOR_DECIBELS) / -FLOOR_DECIBELS
        return min(max(scaled, 0), 1)
    }

    /// Level of the first channel, which is what the mono transcription path records.
    static func normalizedLevel(of buffer: AVAudioPCMBuffer) -> Float {
        guard let channel = buffer.floatChannelData?[0] else { return 0 }
        let samples = UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength))
        return normalized(rms: rms(of: samples))
    }
}
