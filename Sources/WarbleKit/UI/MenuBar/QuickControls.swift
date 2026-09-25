import SwiftUI

/// Round toggles in the style of Control Center modules.
struct QuickControls: View {
    @Environment(SettingsModel.self) private var settings

    var body: some View {
        HStack(alignment: .top) {
            LanguageTile()
            Spacer(minLength: 0)
            ControlTile(
                title: settings.isToggleMode ? "Toggle" : "Hold",
                symbol: settings.isToggleMode ? "hand.tap.fill" : "hand.point.up.left.fill",
                isOn: settings.isToggleMode
            ) {
                settings.update { $0.toggleMode = FlexBool(!settings.isToggleMode) }
            }
            Spacer(minLength: 0)
            ControlTile(title: "Pill", symbol: "capsule.fill", isOn: settings.showsPill) {
                settings.update { $0.shouldShowRecordingPill = FlexBool(!settings.showsPill) }
            }
            Spacer(minLength: 0)
            ControlTile(
                title: "Sounds",
                symbol: settings.playsSounds ? "speaker.wave.2.fill" : "speaker.slash.fill",
                isOn: settings.playsSounds
            ) {
                settings.update { $0.shouldPlaySounds = FlexBool(!settings.playsSounds) }
            }
        }
    }
}

struct ControlTile: View {
    let title: String
    let symbol: String
    let isOn: Bool
    let action: () -> Void

    static let DIAMETER: CGFloat = 44

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                TileCircle(isOn: isOn) {
                    Image(systemName: symbol)
                        .font(.system(size: 16, weight: .medium))
                        .contentTransition(.symbolEffect(.replace))
                }
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 64)
        }
        .buttonStyle(.plain)
        .accessibilityValue(isOn ? "On" : "Off")
    }
}

/// The circle behind a control: accent when on, a quiet fill when off.
struct TileCircle<Content: View>: View {
    let isOn: Bool
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            Circle().fill(isOn ? AnyShapeStyle(.tint) : AnyShapeStyle(.fill.secondary))
            content.foregroundStyle(isOn ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
        }
        .frame(width: ControlTile.DIAMETER, height: ControlTile.DIAMETER)
        .animation(.smooth(duration: 0.2), value: isOn)
    }
}

/// The language as a tile that opens a menu of every supported language.
private struct LanguageTile: View {
    @Environment(SettingsModel.self) private var settings

    var body: some View {
        Menu {
            Picker("Language", selection: Binding(
                get: { settings.config.language },
                set: { code in settings.update { $0.language = code } }
            )) {
                ForEach(Config.supportedLanguages, id: \.code) { Text($0.name).tag($0.code) }
            }
            .pickerStyle(.inline)
        } label: {
            VStack(spacing: 6) {
                TileCircle(isOn: true) {
                    Text(settings.config.language == "auto" ? "A" : settings.config.language.uppercased())
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                }
                Text(languageName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 64)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
    }

    private var languageName: String {
        let code = settings.config.language
        if code == "auto" { return "Auto" }
        return Config.supportedLanguages.first { $0.code == code }?.name ?? code
    }
}
