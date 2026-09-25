import Observation

/// Calls `onChange` every time a value read inside `track` changes, for the
/// AppKit pieces (status item, pill panel) that cannot use SwiftUI bindings.
@MainActor
func observeContinuously(_ track: @escaping @MainActor () -> Void, onChange: @escaping @MainActor () -> Void) {
    withObservationTracking {
        track()
    } onChange: {
        // The callback fires before the new value is stored, so defer the read.
        Task { @MainActor in
            onChange()
            observeContinuously(track, onChange: onChange)
        }
    }
}
