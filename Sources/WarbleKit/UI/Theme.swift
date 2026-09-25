import SwiftUI

/// Colors and metrics shared by every Warble screen.
enum Theme {
    /// Parakeet green, the one brand color; everything else is system material.
    static let accent = Color(red: 0.16, green: 0.72, blue: 0.47)
    static let accentSecondary = Color(red: 0.10, green: 0.56, blue: 0.62)
    static let brandGradient = LinearGradient(
        colors: [accent, accentSecondary],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cornerRadius: CGFloat = 18
    static let cardPadding: CGFloat = 18
    static let pagePadding: CGFloat = 28
}

/// A rounded glass panel used for cards on the Home and Settings screens.
struct GlassCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(Theme.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: .rect(cornerRadius: Theme.cornerRadius))
    }
}

/// Page title with an optional subtitle, used at the top of each main section.
struct PageHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.largeTitle.weight(.bold))
            if let subtitle {
                Text(subtitle)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
