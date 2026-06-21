import ActivityKit
import Foundation

@MainActor
final class LiveActivityController {
    static let shared = LiveActivityController()

    private var currentActivity: Activity<ClimbActivityAttributes>?
    private var lastStatus: WatchLiveStatus?   // C2: Puffer für Vordergrund-Start

    private init() {}

    func update(with status: WatchLiveStatus?) {
        lastStatus = status
        if let status {
            let state = ClimbActivityAttributes.ContentState(
                startedAt: status.startedAt,
                isPaused: status.isPaused,
                pausedElapsed: status.elapsedSeconds,
                sessionTypeRaw: status.sessionTypeRaw
            )
            if let activity = currentActivity {
                Task { await activity.update(ActivityContent(state: state, staleDate: nil)) }
            } else {
                startActivity(state: state, sessionTypeRaw: status.sessionTypeRaw)
            }
        } else {
            endActivity()
        }
    }

    // C2: beim Vordergrund-Werden erneut versuchen, falls kein laufendes Widget
    func retryIfNeeded() {
        guard currentActivity == nil, let status = lastStatus else { return }
        let state = ClimbActivityAttributes.ContentState(
            startedAt: status.startedAt,
            isPaused: status.isPaused,
            pausedElapsed: status.elapsedSeconds,
            sessionTypeRaw: status.sessionTypeRaw
        )
        startActivity(state: state, sessionTypeRaw: status.sessionTypeRaw)
    }

    private func startActivity(state: ClimbActivityAttributes.ContentState, sessionTypeRaw: String) {
        let info = ActivityAuthorizationInfo()
        guard info.areActivitiesEnabled else {
            print("LiveActivity: areActivitiesEnabled=false – in Einstellungen aktivieren")
            return
        }
        let attrs = ClimbActivityAttributes(
            sportLabel: label(for: sessionTypeRaw),
            sportSymbol: symbol(for: sessionTypeRaw)
        )
        do {
            currentActivity = try Activity.request(
                attributes: attrs,
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
            print("LiveActivity gestartet: \(currentActivity?.id ?? "?")")
        } catch {
            print("LiveActivity start fehlgeschlagen: \(error)")
        }
    }

    private func endActivity() {
        guard let activity = currentActivity else { return }
        Task {
            await activity.end(nil as ActivityContent<ClimbActivityAttributes.ContentState>?, dismissalPolicy: .immediate)
        }
        currentActivity = nil
        lastStatus = nil
    }

    private func label(for raw: String) -> String {
        switch raw {
        case "boulder":   "Bouldern"
        case "lead":      "Vorstieg"
        case "topRope":   "Toprope"
        case "autoBelay": "Autobelay"
        case "training":  "Training"
        default:          "Klettern"
        }
    }

    private func symbol(for raw: String) -> String {
        switch raw {
        case "boulder":   "figure.bouldering"
        case "lead", "topRope", "autoBelay": "figure.climbing"
        case "training":  "figure.strengthtraining.functional"
        default:          "figure.climbing"
        }
    }
}
