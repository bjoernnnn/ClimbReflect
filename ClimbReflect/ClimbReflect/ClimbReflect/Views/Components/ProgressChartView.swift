import SwiftUI
import Charts

struct ProgressChartView: View {
    let points: [WeeklyPoint]

    private var maxMinutes: Int { max(points.map(\.minutes).max() ?? 0, 60) }
    private var yMax: Int { Int(Double(maxMinutes) * 1.2) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Fortschritt")
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    Text("Klettermin. pro Woche")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                let total = points.reduce(0) { $0 + $1.minutes }
                Text("\(total) Min")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
            }

            Chart(points) { point in
                BarMark(
                    x: .value("Woche", point.label),
                    y: .value("Minuten", point.minutes)
                )
                .cornerRadius(6)
                .foregroundStyle(Theme.accentGradient)
            }
            .chartYScale(domain: 0...yMax)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine().foregroundStyle(Theme.surfaceStroke.opacity(0.5))
                    AxisValueLabel() {
                        if let v = value.as(Int.self) {
                            Text("\(v)").foregroundStyle(Theme.textTertiary)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel().foregroundStyle(Theme.textTertiary)
                }
            }
            .frame(height: 170)
        }
        .card()
    }
}

#Preview {
    ProgressChartView(points: StatsEngine.weeklyMinutes(MockData.makeSessions()))
        .padding()
        .background(Theme.bg)
}
