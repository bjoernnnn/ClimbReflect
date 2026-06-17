import ActivityKit
import Foundation

@MainActor
final class LiveActivityController {
    static let shared = LiveActivityController()

    private var currentActivity: Activity<ClimbActivityAttributes>?

    private init() {}

    func update(with status: WatchLiveStatus?) {
        if let status {
            let state = ClimbActivityAttributes.ContentState(
                startedAt: status.startedAt,
                isPaused: status.isPaused,
                pausedElapsed: status.elapsedSeconds,
                sessionTypeRaw: status.sessionTypeRaw
            )
            if let activity = currentActivity {
                Task { await activity.update(using: state) }
            } else {
                startActivity(state: state, sessionTypeRaw: status.sessionTypeRaw)
            }
        } else {
            endActivity()
        }
    }

    private func startActivity(state: ClimbActivityAttributes.ContentState, sessionTypeRaw: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
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
        } catch {
            // Live Activity not available in Simulator — silently ignore
        }
    }

    private func endActivity() {
        guard let activity = currentActivity else { return }
        Task {
            await activity.end(dismissalPolicy: .immediate)
        }
        currentActivity = nil
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
