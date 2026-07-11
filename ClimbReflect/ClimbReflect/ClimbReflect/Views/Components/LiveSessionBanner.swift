import SwiftUI
import WatchConnectivity

struct LiveSessionBanner: View {
    let status: WatchLiveStatus
    @State private var showEndConfirm = false   // RP-15
    @State private var bufferedFeedback = false // LA-2: Befehl nur gepuffert (Uhr nicht erreichbar)

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
                Text(sessionLabel)
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
                // LA-2: ehrliches Feedback statt stiller Nicht-Reaktion (Grundsatz 6) –
                // die Uhr ist gerade nicht erreichbar, der Befehl kommt verzögert an.
                if bufferedFeedback {
                    Text("Wird an die Uhr gesendet …")
                        .font(.caption2)
                        .foregroundStyle(Theme.textTertiary)
                        .transition(.opacity)
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
                    showEndConfirm = true   // RP-15: Rückfrage statt Sofort-Ende
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
        .confirmationDialog("Session auf der Watch beenden?", isPresented: $showEndConfirm, titleVisibility: .visible) {
            Button("Beenden", role: .destructive) { sendCommand("end") }
            Button("Abbrechen", role: .cancel) {}
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(status.isPaused ? Theme.gold.opacity(0.25) : Theme.accent.opacity(0.25), lineWidth: 1)
        )
    }

    private func liveElapsedFormatted() -> String {
        // RP-15: Pausenzeit abziehen, sonst divergieren Watch- und iPhone-Zeit nach jeder Pause
        let paused = status.accumulatedPausedSeconds ?? 0
        let s = max(0, Int(Date().timeIntervalSince(status.startedAt) - paused))
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
            // Fallback: transferUserInfo wird zugestellt sobald Watch erreichbar ist –
            // das kann dauern, deshalb sichtbares Feedback statt stillem "als ob nichts
            // passiert wäre" (Grundsatz 6). Rein visuell, keine Auswirkung auf den Versand.
            WCSession.default.transferUserInfo(payload)
            withAnimation { bufferedFeedback = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation { bufferedFeedback = false }
            }
        }
    }
}
