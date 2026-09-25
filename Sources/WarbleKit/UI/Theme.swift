import SwiftUI

/// Shared metrics. Colors come from the system accent, so Warble follows the
/// color chosen in System Settings like Apple's own apps do.
enum Theme {
    static let pagePadding: CGFloat = 24
    static let rowCornerRadius: CGFloat = 10
}

/// A large symbol in the accent color, used as the hero of a setup step or an empty state.
struct HeroSymbol: View {
    let name: String
    var size: CGFloat = 56

    var body: some View {
        Image(systemName: name)
            .font(.system(size: size, weight: .regular))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.tint)
            .frame(height: size * 1.4)
    }
}
