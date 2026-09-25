import AppKit

/// Forwards system sleep and wake so a recording is not left half-open.
@MainActor
final class SleepWakeObserver {
    private var observers: [NSObjectProtocol] = []

    init(willSleep: @escaping @MainActor () -> Void, didWake: @escaping @MainActor () -> Void) {
        let center = NSWorkspace.shared.notificationCenter
        observers = [
            center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { willSleep() }
            },
            center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { didWake() }
            },
        ]
    }

    deinit {
        let center = NSWorkspace.shared.notificationCenter
        observers.forEach(center.removeObserver)
    }
}
