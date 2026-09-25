import SwiftUI

/// Vertical bars that follow the microphone level, newest on the right.
struct WaveformView: View {
    let levels: [Float]

    static let BAR_WIDTH: CGFloat = 3
    static let BAR_SPACING: CGFloat = 2.5
    static let MIN_HEIGHT: CGFloat = 3
    static let MAX_HEIGHT: CGFloat = 22

    var body: some View {
        HStack(alignment: .center, spacing: Self.BAR_SPACING) {
            ForEach(levels.indices, id: \.self) { index in
                Capsule()
                    .fill(.primary.opacity(0.35 + 0.65 * Double(levels[index])))
                    .frame(width: Self.BAR_WIDTH, height: height(for: index))
            }
        }
        .frame(height: Self.MAX_HEIGHT)
        .animation(.smooth(duration: 0.12), value: levels)
        .accessibilityHidden(true)
    }

    /// Bars near the edges are damped a little so the shape reads as a wave.
    private func height(for index: Int) -> CGFloat {
        let position = Double(index) / Double(max(levels.count - 1, 1))
        let envelope = 0.55 + 0.45 * sin(position * .pi)
        let level = CGFloat(levels[index]) * CGFloat(envelope)
        return Self.MIN_HEIGHT + (Self.MAX_HEIGHT - Self.MIN_HEIGHT) * level
    }
}

/// Three dots that ripple while Parakeet works.
struct TranscribingDots: View {
    var body: some View {
        TimelineView(.animation) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    let phase = time * 5 - Double(index) * 0.7
                    Circle()
                        .fill(.primary)
                        .frame(width: 6, height: 6)
                        .opacity(0.35 + 0.65 * (sin(phase) + 1) / 2)
                        .offset(y: -3 * max(0, sin(phase)))
                }
            }
        }
        .accessibilityLabel("Transcribing")
    }
}
