import Foundation
import SwiftUI

/// Things a screen can ask the app to do, injected so views stay free of AppKit wiring.
struct AppActions {
    var retryModel: @MainActor () -> Void = {}
    var retranscribe: @MainActor (URL) -> Void = { _ in }
    var pauseHotkeys: @MainActor (Bool) -> Void = { _ in }
    var openOnboarding: @MainActor () -> Void = {}
    var finishOnboarding: @MainActor () -> Void = {}
    var setLaunchAtLogin: @MainActor (Bool) -> Bool = { _ in false }
}

private struct AppActionsKey: EnvironmentKey {
    static let defaultValue = AppActions()
}

extension EnvironmentValues {
    var appActions: AppActions {
        get { self[AppActionsKey.self] }
        set { self[AppActionsKey.self] = newValue }
    }
}
