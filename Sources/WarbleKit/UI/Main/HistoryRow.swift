import AVFoundation
import SwiftUI

/// Plays one saved recording at a time from the History screen.
@MainActor
@Observable
final class AudioPlayback {
    private(set) var playingID: HistoryEntry.ID?
    private var player: AVAudioPlayer?
    private var stopTask: Task<Void, Never>?

    func toggle(_ entry: HistoryEntry, url: URL) {
        if playingID == entry.id {
            stop()
            return
        }
        stop()
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.play()
            self.player = player
            playingID = entry.id
            stopTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(player.duration))
                guard !Task.isCancelled else { return }
                self?.stop()
            }
        } catch {
            print("Playback failed: \(error.localizedDescription)")
        }
    }

    func stop() {
        stopTask?.cancel()
        player?.stop()
        player = nil
        playingID = nil
    }
}

struct HistoryRow: View {
    let entry: HistoryEntry
    @Environment(HistoryStore.self) private var history
    @Environment(AudioPlayback.self) private var playback
    @Environment(\.appActions) private var actions
    @State private var isHovering = false
    @State private var didCopy = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            SourceAppIcon(bundleID: entry.appBundleID)
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.text)
                    .textSelection(.enabled)
                    .lineLimit(4)
                Text(metadata)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            buttons.opacity(isHovering || didCopy ? 1 : 0)
        }
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
        .onHover { isHovering = $0 }
        .contextMenu { menu }
    }

    private var audioURL: URL? {
        guard let name = entry.audioFileName else { return nil }
        let url = RecordingStore.recordingsDir.appendingPathComponent(name)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private var metadata: String {
        var parts = [entry.date.formatted(date: .omitted, time: .shortened)]
        if let app = entry.appName { parts.append(app) }
        parts.append("\(entry.wordCount) words")
        parts.append(Duration.seconds(entry.durationSeconds).formatted(.units(allowed: [.minutes, .seconds], width: .narrow)))
        return parts.joined(separator: " · ")
    }

    private var buttons: some View {
        HStack(spacing: 6) {
            if let audioURL {
                Button {
                    playback.toggle(entry, url: audioURL)
                } label: {
                    Image(systemName: playback.playingID == entry.id ? "stop.fill" : "play.fill")
                }
                .help("Play recording")
            }
            Button(action: copy) {
                Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
            }
            .help("Copy text")
        }
        .buttonStyle(.glass)
        .controlSize(.small)
    }

    @ViewBuilder
    private var menu: some View {
        Button("Copy", action: copy)
        if let audioURL {
            Button("Play Recording") { playback.toggle(entry, url: audioURL) }
            Button("Transcribe Again and Copy") { actions.retranscribe(audioURL) }
        }
        Divider()
        Button("Delete", role: .destructive) { history.remove(id: entry.id) }
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(entry.text, forType: .string)
        didCopy = true
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            didCopy = false
        }
    }
}
