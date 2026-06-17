import SwiftUI
import SwiftData

struct DashboardView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Heute", systemImage: "house.fill") }

            StatisticsView()
                .tabItem { Label("Statistik", systemImage: "chart.bar.xaxis") }

            NavigationStack { ProjectsView() }
                .tabItem { Label("Projekte", systemImage: "target") }

            AchievementsView()
                .tabItem { Label("Erfolge", systemImage: "trophy.fill") }
        }
        .tint(Theme.accent)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    let container = try! ModelContainer(
        for: ClimbSession.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    MockData.seedIfNeeded(container.mainContext)
    return DashboardView().modelContainer(container)
}
