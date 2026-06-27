import SwiftUI
import Charts

struct EfficiencyTrendView: View {
    let sessions: [ClimbSession]
    @State private var months: Int = 6

    private var points: [StatsEngine.EfficiencyPoint] {
        StatsEngine.efficiencyTrend(sessions, months: months)
    }
    private var hasData: Bool { points.contains { $0.avgAttemptsToTop != nil } }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Effizienz-Trend")
                        .font(.headline).foregroundStyle(Theme.textPrimary)
                    Text("Ø Versuche bis Top · Flash-Rate")
                        .font(.caption).foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                monthPicker
            }

            if !hasData {
                Text("Erfasse Begehungen mit Tops um den Effizienz-Trend zu sehen.")
                    .font(.subheadline).foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                VStack(spacing: 12) {
                    attemptsChart
                    Divider().background(Theme.surfaceStroke)
                    flashRateChart
                }
            }
        }
        .card()
    }

    private var monthPicker: some View {
        HStack(spacing: 2) {
            ForEach([3, 6, 12], id: \.self) { m in
                let active = months == m
                Button { months = m } label: {
                    Text("\(m)M")
                        .font(.caption2.weight(active ? .bold : .regular))
                        .foregroundStyle(active ? Theme.bg : Theme.textTertiary)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Capsule().fill(active ? Theme.accent : Color.clear))
                }
                .buttonStyle(.plain)
                .animation(.easeInOut(duration: 0.15), value: months)
            }
        }
        .padding(2)
        .background(Capsule().fill(Theme.bgElevated))
    }

    private var attemptsChart: some View {
        let filtered = points.compactMap { p -> (Date, Double)? in
            guard let v = p.avgAttemptsToTop else { return nil }
            return (p.monthStart, v)
        }
        return VStack(alignment: .leading, spacing: 4) {
            Text("Ø Versuche bis Top")
                .font(.caption2.weight(.semibold)).foregroundStyle(Theme.textTertiary)
            if filtered.count >= 2 {
                Chart {
                    ForEach(filtered, id: \.0) { date, v in
                        LineMark(x: .value("Monat", date, unit: .month),
                                 y: .value("Versuche", v))
                            .foregroundStyle(Theme.accent)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                        PointMark(x: .value("Monat", date, unit: .month),
                                  y: .value("Versuche", v))
                            .foregroundStyle(Theme.accent).symbolSize(36)
                    }
                }
                .chartYAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine().foregroundStyle(Theme.surfaceStroke.opacity(0.5))
                        AxisValueLabel().foregroundStyle(Theme.textTertiary)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                .frame(height: 90)
            } else if let f = filtered.first {
                Text(String(format: "Ø %.1f Versuche", f.1))
                    .font(.title3.weight(.bold)).foregroundStyle(Theme.accent)
                    .padding(.vertical, 8)
            }
        }
    }

    private var flashRateChart: some View {
        let filtered = points.compactMap { p -> (Date, Double)? in
            guard let v = p.flashRate else { return nil }
            return (p.monthStart, v)
        }
        return VStack(alignment: .leading, spacing: 4) {
            Text("Flash-Rate")
                .font(.caption2.weight(.semibold)).foregroundStyle(Theme.textTertiary)
            if !filtered.isEmpty {
                Chart {
                    ForEach(filtered, id: \.0) { date, v in
                        BarMark(x: .value("Monat", date, unit: .month),
                                y: .value("Flash-Rate", v))
                            .foregroundStyle(Theme.gold.opacity(0.75))
                            .cornerRadius(3)
                    }
                }
                .chartYScale(domain: 0...1)
                .chartYAxis {
                    AxisMarks(values: [0.0, 0.5, 1.0]) { v in
                        AxisGridLine().foregroundStyle(Theme.surfaceStroke.opacity(0.5))
                        AxisValueLabel {
                            if let d = v.as(Double.self) {
                                Text("\(Int(d * 100))%")
                                    .font(.caption2)
                                    .foregroundStyle(Theme.textTertiary)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                .frame(height: 70)
            }
        }
    }
}

#Preview {
    EfficiencyTrendView(sessions: MockData.makeSessions())
        .padding()
        .background(Theme.bg)
}
