import SwiftUI
import SwiftData

struct StatisticsView: View {
    @Query(sort: \ClimbSession.date, order: .reverse) private var sessions: [ClimbSession]

    private var weekly: [WeeklyPoint] { StatsEngine.weeklyMinutes(sessions) }

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
                        VStack(alignment: .leading, spacing: 24) {
                            ProgressChartView(points: weekly)
                            EfficiencyTrendView(sessions: sessions)
                            GradeProgressView(sessions: sessions)
                            RPETrendView(sessions: sessions)
                            LoadManagementView(sessions: sessions)
                            GradePyramidView(sessions: sessions)
                            TerrainHeatmapView(sessions: sessions)
                            LimiterFrequencyView(sessions: sessions)
                            AntistyleRadarView(sessions: sessions)
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
