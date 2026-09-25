import AppKit
import SwiftUI

/// The icon of the app a dictation went into, or a neutral glyph.
struct SourceAppIcon: View {
    let bundleID: String?
    var size: CGFloat = 24

    var body: some View {
        if let image = Self.icon(for: bundleID) {
            Image(nsImage: image)
                .resizable()
                .frame(width: size, height: size)
        } else {
            Image(systemName: "text.cursor")
                .frame(width: size, height: size)
                .foregroundStyle(.secondary)
        }
    }

    private static func icon(for bundleID: String?) -> NSImage? {
        guard let bundleID,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}
