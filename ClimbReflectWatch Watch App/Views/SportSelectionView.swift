import SwiftUI

// W2.1: Sporttypauswahl beim Session-Start
// Kein eigener NavigationStack: ContentView schaltet via workoutManager.isRunning
// automatisch auf LiveSessionView um (sonst Double-Tap durch konkurrierende Navigation).

struct SportSelectionView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    @State private var showTrainingSetup = false

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                Text("Klettern")
                    .font(.headline)
                    .foregroundStyle(WatchTheme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.top, 4)

                ForEach(WatchSessionType.allCases) { type in
                    Button {
                        if type == .training {
                            showTrainingSetup = true
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
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(WatchTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 6)
        }
        .background(WatchTheme.bg)
        .sheet(isPresented: $showTrainingSetup) {
            TrainingSetupView { target in
                showTrainingSetup = false
                Task { await workoutManager.startWorkout(type: .training, target: target) }
            }
        }
    }
}
