import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<AchievementUnlock> { !$0.seenByUser }, sort: \AchievementUnlock.unlockedAt)
    private var unseenUnlocks: [AchievementUnlock]

    // EP-7: nur .full-Erfolge feiern im Vollbild-Overlay; .quiet läuft über
    // den Toast (EP-8). Reihenfolge-Vorrang: Overlay zuerst, Toast danach.
    private var unseenFullUnlocks: [AchievementUnlock] {
        unseenUnlocks.filter {
            AchievementDefinition.definition(id: $0.definitionID)?.celebration == .full
        }
    }

    @State private var batchTotal = 0

    private var currentUnlock: AchievementUnlock? { unseenFullUnlocks.first }
    private var pagerText: String? {
        guard batchTotal > 1 else { return nil }
        let index = max(1, batchTotal - unseenFullUnlocks.count + 1)
        return "\(index) von \(batchTotal)"
    }

    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Heute", systemImage: "house.fill") }

            FortschrittView()
                .tabItem { Label("Fortschritt", systemImage: "chart.line.uptrend.xyaxis") }

            NavigationStack { ProjectsView() }
                .tabItem { Label("Projekte", systemImage: "target") }

            AchievementsView()
                .tabItem { Label("Erfolge", systemImage: "trophy.fill") }
        }
        .tint(Theme.accent)
        .preferredColorScheme(.dark)
        .overlay {
            if let unlock = currentUnlock {
                AchievementUnlockOverlay(unlock: unlock, pagerText: pagerText) {
                    markSeen(unlock)
                }
                .id(unlock.id)   // frische Choreografie je Unlock (State-Reset)
            }
        }
        .onChange(of: unseenFullUnlocks.count) { _, new in
            if new == 0 { batchTotal = 0 }
            else if new > batchTotal { batchTotal = new }
        }
        .task {
            if !unseenFullUnlocks.isEmpty { batchTotal = unseenFullUnlocks.count }
        }
    }

    private func markSeen(_ unlock: AchievementUnlock) {
        unlock.seenByUser = true
        try? context.save()
    }
}

#Preview {
    let container = try! ModelContainer(
        for: ClimbSession.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    MockData.seedIfNeeded(container.mainContext)
    return DashboardView().modelContainer(container)
}
