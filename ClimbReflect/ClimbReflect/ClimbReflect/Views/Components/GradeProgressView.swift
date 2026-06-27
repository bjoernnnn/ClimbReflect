import SwiftUI
import Charts

struct GradeProgressView: View {
    let sessions: [ClimbSession]

    @AppStorage("boulderScale") private var boulderScale: String = GradeSystem.fontainebleau.rawValue
    @State private var period: ChartPeriod = .threeMonths

    private var system: GradeSystem { GradeSystem(rawValue: boulderScale) ?? .fontainebleau }
    private var trendPoints: [StatsEngine.GradeTrendPoint] { StatsEngine.maxGradeTrend(sessions, months: 6) }

    private var consolidation: [StatsEngine.PyramidEntry] {
        StatsEngine.gradePyramid(period.filter(sessions), system: system)
            .filter { $0.tops >= 3 }
    }

    private var maxSortOrder: Int { trendPoints.map(\.sortOrder).max() ?? 0 }
    private var minSortOrder: Int { trendPoints.map(\.sortOrder).min() ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Grad-Entwicklung")
                        .font(.headline).foregroundStyle(Theme.textPrimary)
                    Text("Höchstgrad pro Monat · Konsolidierung")
                        .font(.caption).foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                ChartPeriodPicker(selection: $period)
            }

            if trendPoints.isEmpty && consolidation.isEmpty {
                Text("Erfasse Tops um deine Grad-Entwicklung zu sehen.")
                    .font(.subheadline).foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                if trendPoints.count >= 2 {
                    trendChart
                    Divider().background(Theme.surfaceStroke)
                }
                consolidationSection
            }
        }
        .card()
    }

    private var trendChart: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Höchstgrad (letzte 6 Monate)")
                .font(.caption2.weight(.semibold)).foregroundStyle(Theme.textTertiary)
            Chart(trendPoints) { p in
                LineMark(x: .value("Monat", p.monthStart, unit: .month),
                         y: .value("Schwierigkeit", p.sortOrder))
                    .foregroundStyle(Theme.gold)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                PointMark(x: .value("Monat", p.monthStart, unit: .month),
                          y: .value("Schwierigkeit", p.sortOrder))
                    .foregroundStyle(Theme.gold)
                    .symbolSize(40)
                    .annotation(position: .top) {
                        Text(p.grade)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                    }
            }
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .frame(height: 90)
        }
    }

    private var consolidationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Konsolidiert (3+ Tops)")
                    .font(.caption2.weight(.semibold)).foregroundStyle(Theme.textTertiary)
                Spacer()
                ChartPeriodPicker(selection: $period)
            }
            if consolidation.isEmpty {
                Text("Noch kein Grad 3× gesendet – drück weiter!")
                    .font(.caption).foregroundStyle(Theme.textTertiary)
            } else {
                HStack(spacing: 6) {
                    ForEach(consolidation.prefix(6)) { entry in
                        VStack(spacing: 3) {
                            Text(entry.grade)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Theme.bg)
                            Text("×\(entry.tops)")
                                .font(.system(size: 9))
                                .foregroundStyle(Theme.bg.opacity(0.7))
                        }
                        .padding(.horizontal, 8).padding(.vertical, 5)
                        .background(Capsule().fill(Theme.accent))
                    }
                    if consolidation.count > 6 {
                        Text("+\(consolidation.count - 6)")
                            .font(.caption2).foregroundStyle(Theme.textTertiary)
                    }
                }
            }
        }
    }
}

#Preview {
    GradeProgressView(sessions: MockData.makeSessions())
        .padding()
        .background(Theme.bg)
}
