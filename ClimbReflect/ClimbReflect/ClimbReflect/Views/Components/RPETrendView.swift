import SwiftUI
import Charts

struct RPETrendView: View {
    let sessions: [ClimbSession]

    @State private var period: ChartPeriod = .fourWeeks

    private var points: [RPEPoint] { StatsEngine.rpeHistory(period.filter(sessions)) }

    private var averageRPE: Double? {
        guard !points.isEmpty else { return nil }
        return Double(points.map(\.rpe).reduce(0, +)) / Double(points.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("RPE-Verlauf")
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    Text("Anstrengung nach Zeitraum")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    ChartPeriodPicker(selection: $period)
                    if let avg = averageRPE {
                        Text(String(format: "Ø %.1f", avg))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(rpeColor(Int(avg.rounded())))
                    }
                }
            }

            if points.isEmpty {
                Text("Trage in deinen Sessions einen RPE-Wert ein, um deinen Verlauf zu sehen.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                Chart(points) { point in
                    AreaMark(
                        x: .value("Datum", point.date),
                        yStart: .value("Basis", 0),
                        yEnd: .value("RPE", point.rpe)
                    )
                    .interpolationMethod(.linear)
                    .foregroundStyle(Theme.accent.opacity(0.12))

                    LineMark(
                        x: .value("Datum", point.date),
                        y: .value("RPE", point.rpe)
                    )
                    .interpolationMethod(.linear)
                    .foregroundStyle(Theme.accentGradient)
                    .lineStyle(StrokeStyle(lineWidth: 2))

                    PointMark(
                        x: .value("Datum", point.date),
                        y: .value("RPE", point.rpe)
                    )
                    .foregroundStyle(Theme.accent)
                    .symbolSize(40)
                }
                .chartYScale(domain: 0...10)
                .chartYAxis {
                    AxisMarks(values: [0, 3, 5, 7, 10]) { value in
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
                .frame(height: 160)
            }
        }
        .card()
    }

    private func rpeColor(_ rpe: Int) -> Color {
        switch rpe {
        case 1...4: return Theme.accent
        case 5...7: return Theme.gold
        default:    return Theme.danger
        }
    }
}

#Preview {
    RPETrendView(sessions: MockData.makeSessions())
        .padding()
        .background(Theme.bg)
}
