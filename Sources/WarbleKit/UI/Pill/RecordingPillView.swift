import SwiftUI

/// One piece of Liquid Glass near the bottom of the screen. It keeps the same
/// glass identity across states, so it morphs from a wide listening capsule
/// into a small transcribing one and then into a check mark.
struct RecordingPillView: View {
    @Environment(AppState.self) private var appState
    @Namespace private var namespace

    static let HEIGHT: CGFloat = 40
    static let MORPH = Animation.spring(response: 0.42, dampingFraction: 0.72)

    var body: some View {
        GlassEffectContainer {
            if let content = PillContent(phase: appState.phase) {
                shape(for: content)
                    .glassEffect(content.glass, in: .capsule)
                    .glassEffectID("pill", in: namespace)
                    .transition(.scale(scale: 0.5, anchor: .bottom).combined(with: .opacity))
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(appState.phase.statusText)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 10)
        .animation(Self.MORPH, value: PillContent(phase: appState.phase))
    }

    @ViewBuilder
    private func shape(for content: PillContent) -> some View {
        switch content {
        case .listening:
            HStack(spacing: 10) {
                RecordingDot()
                WaveformView(levels: appState.levels)
            }
            .padding(.horizontal, 16)
            .frame(height: Self.HEIGHT)
        case .transcribing:
            TranscribingDots()
                .frame(width: 64, height: Self.HEIGHT)
        case .done:
            Image(systemName: "checkmark")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.green)
                .frame(width: Self.HEIGHT, height: Self.HEIGHT)
                .transition(.symbolEffect(.drawOn))
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.callout.weight(.medium))
                .symbolRenderingMode(.multicolor)
                .lineLimit(1)
                .padding(.horizontal, 16)
                .frame(height: Self.HEIGHT)
                .frame(maxWidth: 320)
        }
    }
}

private struct RecordingDot: View {
    var body: some View {
        Circle()
            .fill(.red)
            .frame(width: 8, height: 8)
            .phaseAnimator([1.0, 0.35]) { dot, opacity in
                dot.opacity(opacity)
            } animation: { _ in .easeInOut(duration: 0.7) }
    }
}

/// What the pill shows for each dictation phase; nil means hidden.
enum PillContent: Equatable {
    case listening
    case transcribing
    case done
    case failed(String)

    init?(phase: DictationPhase) {
        switch phase {
        case .recording: self = .listening
        case .transcribing: self = .transcribing
        case .inserted, .copied: self = .done
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
