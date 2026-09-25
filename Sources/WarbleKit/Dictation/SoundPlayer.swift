import AppKit

/// Short system sounds that confirm the key press without looking at the screen.
@MainActor
final class SoundPlayer {
    enum Cue {
        case start
        case stop
        case failure

        var systemSoundName: String {
            switch self {
            case .start: return "Tink"
            case .stop: return "Pop"
            case .failure: return "Basso"
            }
        }
    }

    /// Quiet enough not to leak into the recording that starts right after.
    static let VOLUME: Float = 0.25

    var isEnabled = true
    private var cache: [String: NSSound] = [:]

    func play(_ cue: Cue) {
        guard isEnabled, let sound = sound(named: cue.systemSoundName) else { return }
        sound.stop()
        sound.volume = Self.VOLUME
        sound.play()
    }

    private func sound(named name: String) -> NSSound? {
        if let cached = cache[name] { return cached }
        let sound = NSSound(named: NSSound.Name(name))
        cache[name] = sound
        return sound
    }
}
