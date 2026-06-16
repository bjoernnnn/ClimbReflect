import SwiftUI

// W2.1: Sporttypauswahl beim Session-Start

struct SportSelectionView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    @State private var selected: WatchSessionType = .boulder
    @State private var navigateToSession = false

    var body: some View {
        NavigationStack {
            List(WatchSessionType.allCases) { type in
                Button {
                    selected = type
                    Task {
                        await workoutManager.startWorkout(type: type)
                        navigateToSession = true
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: type.symbol)
                            .foregroundStyle(WatchTheme.accent)
                            .frame(width: 24)
                        Text(type.label)
                            .foregroundStyle(WatchTheme.textPrimary)
                    }
                }
                .listRowBackground(WatchTheme.surface)
            }
            .navigationTitle("Klettern")
            .navigationDestination(isPresented: $navigateToSession) {
                LiveSessionView()
            }
        }
    }
}
