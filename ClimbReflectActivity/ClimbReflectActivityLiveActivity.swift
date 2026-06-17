import ActivityKit
import WidgetKit
import SwiftUI

private extension Color {
    static let crAccent = Color(red: 0.4, green: 0.8, blue: 0.4)
    static let crGold   = Color(red: 1.0, green: 0.8, blue: 0.2)
    static let crBg     = Color(red: 0.08, green: 0.08, blue: 0.10)
}

private func elapsedString(_ seconds: Int) -> String {
    let h = seconds / 3600
    let m = (seconds % 3600) / 60
    let s = seconds % 60
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
}

struct ClimbReflectActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ClimbActivityAttributes.self) { context in
            LockScreenView(attributes: context.attributes, state: context.state)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(context.attributes.sportLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                    } icon: {
                        Image(systemName: context.attributes.sportSymbol)
                            .foregroundStyle(context.state.isPaused ? .crGold : .crAccent)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    timerView(state: context.state)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(context.state.isPaused ? .crGold : .crAccent)
                        .monospacedDigit()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if context.state.isPaused {
                        Label("Pausiert", systemImage: "pause.fill")
                            .font(.caption2)
                            .foregroundStyle(.crGold)
                    }
                }
            } compactLeading: {
                Image(systemName: context.attributes.sportSymbol)
                    .foregroundStyle(context.state.isPaused ? .crGold : .crAccent)
            } compactTrailing: {
                timerView(state: context.state)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(context.state.isPaused ? .crGold : .crAccent)
                    .monospacedDigit()
            } minimal: {
                Image(systemName: context.attributes.sportSymbol)
                    .foregroundStyle(context.state.isPaused ? .crGold : .crAccent)
            }
        }
    }

    @ViewBuilder
    private func timerView(state: ClimbActivityAttributes.ContentState) -> some View {
        if state.isPaused {
            Text(elapsedString(state.pausedElapsed))
        } else {
            Text(timerInterval: state.startedAt...Date.distantFuture, countsDown: false)
        }
    }
}

private struct LockScreenView: View {
    let attributes: ClimbActivityAttributes
    let state: ClimbActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(state.isPaused ? Color.crGold.opacity(0.15) : Color.crAccent.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: attributes.sportSymbol)
                    .font(.system(size: 20))
                    .foregroundStyle(state.isPaused ? .crGold : .crAccent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(attributes.sportLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                if state.isPaused {
                    Label("Pausiert", systemImage: "pause.fill")
                        .font(.caption2)
                        .foregroundStyle(.crGold)
                }
            }

            Spacer()

            if state.isPaused {
                Text(elapsedString(state.pausedElapsed))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.crGold)
                    .monospacedDigit()
            } else {
                Text(timerInterval: state.startedAt...Date.distantFuture, countsDown: false)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.crAccent)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.crBg)
        .activityBackgroundTint(Color.crBg)
        .activitySystemActionForegroundColor(.white)
    }
}
