import SwiftUI
import SwiftData

struct StatisticsView: View {
    @Query(sort: \ClimbSession.date, order: .reverse) private var sessions: [ClimbSession]

    // Nur Klettersessions – die Karte ist mit "Klettermin. pro Woche" beschriftet
    private var weekly: [WeeklyPoint] { StatsEngine.weeklyMinutes(sessions.filter(\.isClimbing)) }

    var body: some View {
        NavigationStack {
            ZStack {
                MountainBackground()
                if sessions.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.system(size: 48))
                            .foregroundStyle(Theme.textTertiary)
                        Text("Noch keine Daten")
                            .font(.headline)
                            .foregroundStyle(Theme.textPrimary)
                        Text("Erfasse Sessions um Statistiken zu sehen.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    ScrollView {
                        // RP-14: Lazy rendern – Chart-Karten (inkl. StatsEngine-Berechnung)
                        // erst beim Sichtbarwerden aufbauen, skaliert mit Session-Zahl.
                        LazyVStack(alignment: .leading, spacing: 24) {
                            ProgressChartView(points: weekly)
                            // EFF: reaktivieren nach TODO-EFFIZIENZ (FB-8: Watch-Ascents haben
                            // attempts=1 → „Ø Versuche bis Top" irreführend; View+Engine bleiben)
                            GradeProgressView(sessions: sessions)
                            FingerStrengthTrendView(sessions: sessions)
                            GradePyramidView(sessions: sessions)
                            TerrainHeatmapView(sessions: sessions)
                            FocusPerformanceView(sessions: sessions)
                            LimiterFrequencyView(sessions: sessions)
                            AntistyleRadarView(sessions: sessions)
                            OutdoorConditionsView(sessions: sessions)
                            SessionTypeChartView(sessions: sessions)
                            WeeklyRecapView(sessions: sessions)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Statistik")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }
}
