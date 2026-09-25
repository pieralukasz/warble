import SwiftUI

enum OnboardingStep: Int, CaseIterable {
    case welcome
    case microphone
    case accessibility
    case model
    case shortcut
    case tryIt
}

/// First-run setup: permissions, model download, hotkey, and a practice run.
struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.appActions) private var actions
    @State private var step: OnboardingStep
    @State private var permissions = PermissionStatus.current()

    init(initialStep: OnboardingStep = .welcome) {
        _step = State(initialValue: initialStep)
    }

    /// How often permission status is re-read while a step waits for System Settings.
    static let PERMISSION_POLL: Duration = .seconds(1)

    var body: some View {
        VStack(spacing: 0) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 48)
                .padding(.top, 36)
                .id(step)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            footer
        }
        .frame(width: 640, height: 540)
        .tint(Theme.accent)
        .task { await pollPermissions() }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome: WelcomeStep()
        case .microphone: MicrophoneStep(status: permissions.microphone, refresh: refresh)
        case .accessibility: AccessibilityStep(isGranted: permissions.accessibility)
        case .model: ModelStep()
        case .shortcut: ShortcutStep()
        case .tryIt: TryItStep()
        }
    }

    private var footer: some View {
        HStack {
            StepDots(current: step)
            Spacer()
            if step != .welcome {
                Button("Back") { move(by: -1) }
                    .buttonStyle(.glass)
            }
            Button(step == .tryIt ? "Start Using Warble" : "Continue") {
                step == .tryIt ? actions.finishOnboarding() : move(by: 1)
            }
            .buttonStyle(.glassProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(!canContinue)
        }
        .controlSize(.large)
        .padding(24)
    }

    private var canContinue: Bool {
        switch step {
        case .microphone: return permissions.microphone == .granted
        case .accessibility: return permissions.accessibility
        case .model: return appState.model.isReady
        default: return true
        }
    }

    private func move(by offset: Int) {
        guard let next = OnboardingStep(rawValue: step.rawValue + offset) else { return }
        withAnimation(.smooth(duration: 0.35)) { step = next }
    }

    private func refresh() {
        permissions = PermissionStatus.current()
    }

    private func pollPermissions() async {
        while !Task.isCancelled {
            refresh()
            try? await Task.sleep(for: Self.PERMISSION_POLL)
        }
    }
}

private struct StepDots: View {
    let current: OnboardingStep

    var body: some View {
        HStack(spacing: 6) {
            ForEach(OnboardingStep.allCases, id: \.self) { step in
                Capsule()
                    .fill(step == current ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(.quaternary))
                    .frame(width: step == current ? 18 : 6, height: 6)
            }
        }
        .animation(.smooth, value: current)
        .accessibilityLabel("Step \(current.rawValue + 1) of \(OnboardingStep.allCases.count)")
    }
}

/// Shared layout for a step: big symbol, title, explanation, then the step's controls.
struct StepLayout<Controls: View>: View {
    let symbol: String
    let title: String
    let message: String
    @ViewBuilder var controls: Controls

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: symbol)
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 92, height: 92)
                .background(Theme.brandGradient, in: .rect(cornerRadius: 24))
            Text(title)
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)
            Text(message)
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            controls
                .padding(.top, 6)
            Spacer(minLength: 0)
        }
    }
}
