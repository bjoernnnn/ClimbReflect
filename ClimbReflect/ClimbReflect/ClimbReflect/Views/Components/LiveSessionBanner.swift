import SwiftUI
import WatchConnectivity

struct LiveSessionBanner: View {
    let status: WatchLiveStatus

    private var sessionLabel: String {
        switch status.sessionTypeRaw {
        case "boulder":   "Bouldern"
        case "lead":      "Vorstieg"
        case "topRope":   "Toprope"
        case "autoBelay": "Autobelay"
        case "training":  "Training"
        default:          "Session"
        }
    }

    private var reachable: Bool {
        WCSession.isSupported() && WCSession.default.isReachable
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(status.isPaused ? Theme.gold.opacity(0.15) : Theme.accent.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: status.isPaused ? "pause.fill" : "applewatch")
                    .font(.system(size: 17))
                    .foregroundStyle(status.isPaused ? Theme.gold : Theme.accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("\(sessionLabel) auf der Watch")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                // Sekündliche Anzeige lokal via TimelineView – kein Watch-Funk
                if status.isPaused {
                    Text(status.elapsedFormatted)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Theme.gold)
                } else {
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        Text(liveElapsedFormatted())
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Theme.accent)
                    }
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    sendCommand(status.isPaused ? "resume" : "pause")
                } label: {
                    Image(systemName: status.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(reachable ? Theme.textPrimary : Theme.textTertiary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Theme.bgElevated))
                }
                .buttonStyle(.plain)
                .disabled(!reachable)

                Button {
                    sendCommand("end")
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(reachable ? Theme.danger : Theme.textTertiary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(reachable ? Theme.danger.opacity(0.12) : Theme.bgElevated))
                }
                .buttonStyle(.plain)
                .disabled(!reachable)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(status.isPaused ? Theme.gold.opacity(0.25) : Theme.accent.opacity(0.25), lineWidth: 1)
        )
    }

    private func liveElapsedFormatted() -> String {
        let s = Int(Date().timeIntervalSince(status.startedAt))
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, sec)
            : String(format: "%02d:%02d", m, sec)
    }

    private func sendCommand(_ command: String) {
        guard reachable else { return }
        WCSession.default.sendMessage(["watchCommand": command], replyHandler: nil)
    }
}
