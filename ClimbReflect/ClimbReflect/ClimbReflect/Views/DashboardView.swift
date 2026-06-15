import SwiftUI
import SwiftData
#if canImport(HealthKit)
import HealthKit
#endif

struct DashboardView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ClimbSession.date, order: .reverse) private var sessions: [ClimbSession]

    @State private var importMessage: String?
    @State private var isImporting = false
    @State private var showAddSession = false
    @State private var showSettings = false

    private var healthKitAvailable: Bool {
        #if canImport(HealthKit)
        return HKHealthStore.isHealthDataAvailable()
        #else
        return false
        #endif
    }

    private var achievements: [Achievement] { StatsEngine.achievements(for: sessions) }
    private var weekly: [WeeklyPoint] { StatsEngine.weeklyMinutes(sessions) }
    private var unlockedCount: Int { achievements.filter(\.isUnlocked).count }

    var body: some View {
        NavigationStack {
            ZStack {
                MountainBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header

                        statRow

                        sectionHeader("Erfolge", trailing: "\(unlockedCount)/\(achievements.count)")
                        achievementsRow

                        ProgressChartView(points: weekly)

                        LimiterFrequencyView(sessions: sessions)

                        recentSessions
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 16) {
                        Button {
                            showAddSession = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                    .tint(Theme.accent)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if healthKitAvailable {
                        Button {
                            Task { await importFromRedpoint() }
                        } label: {
                            Image(systemName: isImporting ? "arrow.triangle.2.circlepath" : "heart.text.square")
                        }
                        .accessibilityLabel("Aus Apple Health importieren")
                        .tint(Theme.accent)
                        .disabled(isImporting)
                    }
                }
            }
            .sheet(isPresented: $showAddSession) {
                ManualSessionView()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .alert("Apple Health / Redpoint",
                   isPresented: .constant(importMessage != nil),
                   presenting: importMessage) { _ in
                Button("OK") { importMessage = nil }
            } message: { Text($0) }
        }
        .preferredColorScheme(.dark)
        .tint(Theme.accent)
    }

    // MARK: - Abschnitte

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(greeting)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            Text("Bereit für den nächsten Zug?")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private var statRow: some View {
        HStack(spacing: 12) {
            StatTile(value: "\(sessions.count)", label: "Sessions gesamt", symbol: "figure.climbing")
            StatTile(value: "\(StatsEngine.weekStreak(sessions))", label: "Wochenstreak", symbol: "flame.fill")
            StatTile(value: "\(StatsEngine.sessionsThisWeek(sessions))", label: "Diese Woche", symbol: "calendar")
        }
    }

    private var achievementsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(achievements) { AchievementCard(achievement: $0) }
            }
            .padding(.horizontal, 2)
        }
        .scrollClipDisabled()
    }

    private var recentSessions: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Letzte Sessions")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                NavigationLink(destination: AllSessionsView()) {
                    Text("Alle anzeigen")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                }
            }
            if sessions.isEmpty {
                Button { showAddSession = true } label: {
                    VStack(spacing: 12) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(Theme.accent)
                        Text("Erste Session anlegen")
                            .font(.headline)
                            .foregroundStyle(Theme.textPrimary)
                        Text("Oder importiere deine Einheiten aus Apple Health")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                }
                .buttonStyle(.plain)
            } else {
                ForEach(sessions.prefix(5)) { session in
                    NavigationLink(destination: SessionDetailView(session: session)) {
                        SessionRow(session: session)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func sectionHeader(_ title: String, trailing: String?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.gold)
            }
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<11:  return "Guten Morgen 👋"
        case 11..<17: return "Hallo 👋"
        case 17..<22: return "Guten Abend 👋"
        default:      return "Spät unterwegs 🌙"
        }
    }

    // MARK: - Redpoint-Import (HealthKit)

    private func importFromRedpoint() async {
        isImporting = true
        defer { isImporting = false }
        do {
            let imported = try await RedpointHealthService.shared.importNewSessions(into: context)
            importMessage = imported > 0
                ? "\(imported) neue Session(s) aus Redpoint importiert."
                : "Keine neuen Kletter-Workouts gefunden."
        } catch {
            importMessage = "Import nicht möglich: \(error.localizedDescription)\n\nLäuft die App auf einem echten iPhone mit erlaubtem Health-Zugriff?"
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: ClimbSession.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    MockData.seedIfNeeded(container.mainContext)
    return DashboardView().modelContainer(container)
}
