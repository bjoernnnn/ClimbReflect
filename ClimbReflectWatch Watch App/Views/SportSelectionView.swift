import SwiftUI

// W2.1: Sporttypauswahl beim Session-Start
// Kein eigener NavigationStack: ContentView schaltet via workoutManager.isRunning
// automatisch auf LiveSessionView um (sonst Double-Tap durch konkurrierende Navigation).

struct SportSelectionView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    @State private var showingTrainingTargets = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 6) {
                    if showingTrainingTargets {
                        trainingTargetList
                    } else {
                        sportList
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 6)
            }
            .background(WatchTheme.bg)
        }
    }

    private var sportList: some View {
        Group {
            Text("Klettern")
                .font(.headline)
                .foregroundStyle(WatchTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.top, 4)

            ForEach(WatchSessionType.allCases) { type in
                Button {
                    if type == .training {
                        showingTrainingTargets = true
                    } else {
                        Task { await workoutManager.startWorkout(type: type) }
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: type.symbol)
                            .foregroundStyle(WatchTheme.accent)
                            .frame(width: 24)
                        Text(type.label)
                            .foregroundStyle(WatchTheme.textPrimary)
                        Spacer()
                        if type == .training {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11))
                                .foregroundStyle(WatchTheme.textTert)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .background(WatchTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var trainingTargetList: some View {
        Group {
            Button { showingTrainingTargets = false } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Zurück")
                        .font(.footnote.weight(.semibold))
                }
                .foregroundStyle(WatchTheme.textSecond)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.top, 4)
            }
            .buttonStyle(.plain)

            ForEach(WatchTrainingTarget.allCases) { target in
                Button {
                    Task { await workoutManager.startWorkout(type: .training, target: target) }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: target.symbol)
                            .foregroundStyle(WatchTheme.accent)
                            .frame(width: 24)
                        Text(target.label)
                            .foregroundStyle(WatchTheme.textPrimary)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .background(WatchTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
