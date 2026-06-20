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

            VStack(alignment: .leading, spacing: 4) {
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
                HStack(spacing: 10) {
                    if let hr = status.heartRate {
                        Label(String(format: "%.0f bpm", hr), systemImage: "heart.fill")
                            .font(.caption2)
                            .foregroundStyle(Theme.danger)
                    }
                    if let kcal = status.activeEnergyKcal {
                        Label(String(format: "%.0f kcal", kcal), systemImage: "flame.fill")
                            .font(.caption2)
                            .foregroundStyle(Theme.gold)
                    }
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    sendCommand(status.isPaused ? "resume" : "pause")
                } label: {
                    Image(systemName: status.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Theme.bgElevated))
                }
                .buttonStyle(.plain)

                Button {
                    sendCommand("end")
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.danger)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Theme.danger.opacity(0.12)))
                }
                .buttonStyle(.plain)
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
        let payload: [String: Any] = ["watchCommand": command]
        if reachable {
            WCSession.default.sendMessage(payload, replyHandler: nil)
        } else {
            // Fallback: transferUserInfo wird zugestellt sobald Watch erreichbar ist
            WCSession.default.transferUserInfo(payload)
        }
    }
}
