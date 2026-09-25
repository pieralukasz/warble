import AVFoundation
import ApplicationServices

/// A snapshot of the three macOS privacy grants Warble can need.
struct PermissionStatus: Equatable {
    enum Microphone: Equatable {
        case granted
        case denied
        case notDetermined
    }

    var microphone: Microphone
    var accessibility: Bool
    var screenRecording: Bool

    static func current() -> PermissionStatus {
        // Previews show the granted state on every Mac, so screenshots match.
        if PreviewMode.isActive {
            return PermissionStatus(microphone: .granted, accessibility: true, screenRecording: true)
        }
        return PermissionStatus(
            microphone: microphoneStatus(),
            accessibility: AXIsProcessTrusted(),
            screenRecording: Permissions.hasScreenRecording
        )
    }

    private static func microphoneStatus() -> Microphone {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return .granted
        case .notDetermined: return .notDetermined
        default: return .denied
        }
    }

    static func requestMicrophone() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .audio)
    }

    static func openMicrophoneSettings() {
        Permissions.openSettingsPane("Privacy_Microphone")
    }
}
