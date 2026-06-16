import SwiftUI

// W2.1: Sporttypauswahl beim Session-Start
// ScrollView statt List: verhindert watchOS-typisches "erst fokussieren, dann tippen"

struct SportSelectionView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    @State private var showTrainingSetup = false
    @State private var navigateToSession = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(WatchSessionType.allCases) { type in
                        Button {
                            if type == .training {
                                showTrainingSetup = true
                            } else {
                                Task {
                                    await workoutManager.startWorkout(type: type)
                                    navigateToSession = true
                                }
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
            .navigationTitle("Klettern")
            .navigationDestination(isPresented: $navigateToSession) {
                LiveSessionView()
            }
            .sheet(isPresented: $showTrainingSetup) {
                TrainingSetupView { target in
                    showTrainingSetup = false
                    Task {
                        await workoutManager.startWorkout(type: .training, target: target)
                        navigateToSession = true
                    }
                }
            }
        }
    }
}
