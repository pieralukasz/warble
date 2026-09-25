import SwiftUI

/// One number with a label, for the Home screen stats row.
struct StatTile: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(Theme.accent)
            Text(value)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(title)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(Theme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: Theme.cornerRadius))
        .accessibilityElement(children: .combine)
    }
}

/// The icon of the app a dictation went into, or a neutral glyph.
struct SourceAppIcon: View {
    let bundleID: String?

    var body: some View {
        if let image = Self.icon(for: bundleID) {
            Image(nsImage: image)
                .resizable()
                .frame(width: 28, height: 28)
        } else {
            Image(systemName: "text.cursor")
                .frame(width: 28, height: 28)
                .foregroundStyle(.secondary)
        }
    }

    private static func icon(for bundleID: String?) -> NSImage? {
        guard let bundleID,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}
