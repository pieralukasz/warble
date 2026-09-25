import Foundation

/// Explains a dictation that produced no text, so the pill says why instead of
/// quietly disappearing.
enum SilentDictation {
    /// About -45 dBFS: quieter than any normal speech reaching the recorder.
    static let SILENCE_PEAK_LEVEL: Float = 0.1

    static func message(source: AudioCaptureSource, peakLevel: Float) -> String {
        guard peakLevel < SILENCE_PEAK_LEVEL else { return "No words recognized" }
        switch source {
        case .microphone: return "No sound from the microphone"
        case .systemAudio: return "No sound from system audio"
        case .microphoneAndSystemAudio: return "No sound recorded"
        }
    }
}
