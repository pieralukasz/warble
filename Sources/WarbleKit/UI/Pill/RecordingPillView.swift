import SwiftUI

/// The small glass capsule near the bottom of the screen while dictating.
struct RecordingPillView: View {
    @Environment(AppState.self) private var appState
    @Namespace private var namespace

    static let HEIGHT: CGFloat = 44

    var body: some View {
        GlassEffectContainer {
            if let content = PillContent(phase: appState.phase) {
                pill(for: content)
                    .transition(.scale(scale: 0.6, anchor: .bottom).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 8)
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: appState.phase)
    }

    @ViewBuilder
    private func pill(for content: PillContent) -> some View {
        HStack(spacing: 10) {
            switch content {
            case .listening:
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                    .phaseAnimator([1.0, 0.35]) { dot, opacity in
                        dot.opacity(opacity)
                    } animation: { _ in .easeInOut(duration: 0.7) }
                WaveformView(levels: appState.levels)
            case .transcribing:
                TranscribingDots()
            case .done(let label):
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.accent)
                Text(label).font(.callout.weight(.medium))
            case .failed(let message):
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                Text(message)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: Self.HEIGHT)
        .frame(maxWidth: 320)
        .glassEffect(content.glass, in: .capsule)
        .glassEffectID("pill", in: namespace)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(appState.phase.statusText)
    }
}

/// What the pill shows for each dictation phase; nil means hidden.
enum PillContent: Equatable {
    case listening
    case transcribing
    case done(String)
    case failed(String)

    init?(phase: DictationPhase) {
        switch phase {
        case .recording: self = .listening
        case .transcribing: self = .transcribing
        case .inserted: self = .done("Typed")
        case .copied: self = .done("Copied")
        case .error(let message): self = .failed(message)
        case .idle, .preparing, .needsAccessibility: return nil
        }
    }

    var glass: Glass {
        switch self {
        case .failed: return .regular.tint(.red.opacity(0.25))
        default: return .regular
        }
    }
}
