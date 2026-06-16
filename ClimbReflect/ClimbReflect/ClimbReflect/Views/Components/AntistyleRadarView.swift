import SwiftUI
import Charts

// P3.7: Send-Rate pro Stil-Bucket — zeigt Schwächen als Trainingskarte

struct AntistyleRadarView: View {
    let sessions: [ClimbSession]

    @State private var period: ChartPeriod = .fourWeeks

    private var rates: [StatsEngine.StyleSendRate] {
        StatsEngine.antistyleRates(period.filter(sessions))
    }

    var body: some View {
        if rates.isEmpty { EmptyView() } else {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Antistyle-Analyse")
                            .font(.headline)
                            .foregroundStyle(Theme.textPrimary)
                        Text("Send-Rate nach Stil · Schwächen zuerst")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    ChartPeriodPicker(selection: $period)
                }

                Chart(rates) { entry in
                    BarMark(
                        x: .value("Rate", entry.sendRate),
                        y: .value("Stil", entry.label)
                    )
                    .foregroundStyle(barColor(entry.sendRate))
                    .annotation(position: .overlay, alignment: .trailing) {
                        Text("\(Int(entry.sendRate * 100))%")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.trailing, 4)
                    }
                }
                .chartXScale(domain: 0...1.15)
                .chartXAxis {
                    AxisMarks(values: [0, 0.25, 0.5, 0.75, 1.0]) { val in
                        AxisGridLine().foregroundStyle(Theme.bgElevated)
                        AxisValueLabel {
                            if let d = val.as(Double.self) {
                                Text("\(Int(d * 100))%")
                                    .font(.system(size: 9))
                                    .foregroundStyle(Theme.textTertiary)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { val in
                        AxisValueLabel {
                            if let s = val.as(String.self) {
                                Text(s)
                                    .font(.caption2)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                    }
                }
                .frame(height: CGFloat(rates.count) * 28 + 20)

                // Schwächstes Bucket hervorheben
                if let weakest = rates.first, weakest.sendRate < 0.5 {
                    HStack(spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(Theme.gold)
                            .font(.caption)
                        Text("Tipp: Mehr an \(weakest.label)-Zügen üben (\(weakest.totalAscents) Versuche, \(Int(weakest.sendRate * 100))% Send-Rate)")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.gold.opacity(0.08)))
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(Theme.surface))
        }
    }

    private func barColor(_ rate: Double) -> Color {
        switch rate {
        case ..<0.3:  return Theme.danger
        case ..<0.6:  return Theme.gold
        default:       return Theme.accent
        }
    }
}
