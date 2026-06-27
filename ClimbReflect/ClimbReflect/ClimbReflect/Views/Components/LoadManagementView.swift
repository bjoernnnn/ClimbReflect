import SwiftUI
import Charts

struct LoadManagementView: View {
    let sessions: [ClimbSession]
    @State private var weeks: Int = 8

    private var points: [StatsEngine.WeekLoad] {
        StatsEngine.trainingLoad(sessions, weeks: weeks)
    }

    private var hasAcwr: Bool { points.contains { $0.acwr != nil } }
    private var maxLoad: Int { points.map(\.load).max() ?? 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Trainingsbelastung")
                        .font(.headline).foregroundStyle(Theme.textPrimary)
                    Text("sRPE (RPE × Minuten) · ACWR-Ratio")
                        .font(.caption).foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                weekPicker
            }

            if points.allSatisfy({ $0.load == 0 }) {
                Text("Erfasse Sessions mit RPE-Wert um die Belastung zu sehen.")
                    .font(.subheadline).foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                loadChart
                if hasAcwr {
                    Divider().background(Theme.surfaceStroke)
                    acwrChart
                    acwrLegend
                }
            }
        }
        .card()
    }

    private var weekPicker: some View {
        HStack(spacing: 2) {
            ForEach([4, 8], id: \.self) { w in
                let active = weeks == w
                Button { weeks = w } label: {
                    Text("\(w)W")
                        .font(.caption2.weight(active ? .bold : .regular))
                        .foregroundStyle(active ? Theme.bg : Theme.textTertiary)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Capsule().fill(active ? Theme.accent : Color.clear))
                }
                .buttonStyle(.plain)
                .animation(.easeInOut(duration: 0.15), value: weeks)
            }
        }
        .padding(2)
        .background(Capsule().fill(Theme.bgElevated))
    }

    private var loadChart: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Wöchentliche Last (sRPE)")
                .font(.caption2.weight(.semibold)).foregroundStyle(Theme.textTertiary)
            Chart(points) { point in
                BarMark(x: .value("Woche", point.weekStart, unit: .weekOfYear),
                        y: .value("Last", point.load))
                    .foregroundStyle(
                        (point.acwr ?? 1) > 1.5 ? Theme.danger.opacity(0.75) :
                        (point.acwr ?? 1) > 1.2 ? Theme.gold.opacity(0.75) :
                        Theme.accent.opacity(0.75)
                    )
                    .cornerRadius(3)
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine().foregroundStyle(Theme.surfaceStroke.opacity(0.5))
                    AxisValueLabel().foregroundStyle(Theme.textTertiary)
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisValueLabel(format: .dateTime.day().month())
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .frame(height: 100)
        }
    }

    private var acwrChart: some View {
        let acwrPoints = points.compactMap { p -> (Date, Double)? in
            guard let a = p.acwr else { return nil }
            return (p.weekStart, a)
        }
        return VStack(alignment: .leading, spacing: 4) {
            Text("ACWR (Akutlast / Chronische Last)")
                .font(.caption2.weight(.semibold)).foregroundStyle(Theme.textTertiary)
            if acwrPoints.count >= 2 {
                Chart {
                    RuleMark(y: .value("Grenze", 1.5))
                        .foregroundStyle(Theme.danger.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    RuleMark(y: .value("Ideal hoch", 1.3))
                        .foregroundStyle(Theme.gold.opacity(0.35))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    RuleMark(y: .value("Ideal niedrig", 0.8))
                        .foregroundStyle(Theme.gold.opacity(0.35))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    ForEach(acwrPoints, id: \.0) { date, acwr in
                        LineMark(x: .value("Woche", date, unit: .weekOfYear),
                                 y: .value("ACWR", acwr))
                            .foregroundStyle(acwr > 1.5 ? Theme.danger : acwr > 1.2 ? Theme.gold : Theme.accent)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                        PointMark(x: .value("Woche", date, unit: .weekOfYear),
                                  y: .value("ACWR", acwr))
                            .foregroundStyle(acwr > 1.5 ? Theme.danger : acwr > 1.2 ? Theme.gold : Theme.accent)
                            .symbolSize(30)
                    }
                }
                .chartYScale(domain: 0...2.5)
                .chartYAxis {
                    AxisMarks(values: [0.0, 0.8, 1.3, 1.5, 2.0]) { v in
                        AxisGridLine().foregroundStyle(Theme.surfaceStroke.opacity(0.4))
                        AxisValueLabel().foregroundStyle(Theme.textTertiary)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisValueLabel(format: .dateTime.day().month())
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                .frame(height: 90)
            }
        }
    }

    private var acwrLegend: some View {
        HStack(spacing: 12) {
            legendItem(color: Theme.accent, label: "< 1.2 Optimal")
            legendItem(color: Theme.gold, label: "1.2–1.5 Hoch")
            legendItem(color: Theme.danger, label: "> 1.5 Risiko")
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label).font(.caption2).foregroundStyle(Theme.textTertiary)
        }
    }
}

#Preview {
    LoadManagementView(sessions: MockData.makeSessions())
        .padding()
        .background(Theme.bg)
}
