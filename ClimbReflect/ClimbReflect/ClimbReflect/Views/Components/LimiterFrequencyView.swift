import SwiftUI
import Charts

struct LimiterFrequencyView: View {
    let sessions: [ClimbSession]

    private struct LimiterStat: Identifiable {
        let id: String
        let label: String
        let count: Int
    }

    private var data: [LimiterStat] {
        Limiter.allCases
            .map { l in
                LimiterStat(id: l.rawValue, label: l.label,
                            count: sessions.filter { $0.limiters.contains(l) }.count)
            }
            .filter { $0.count > 0 }
            .sorted { $0.count > $1.count }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Häufigste Schwächen")
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    Text("Limitierende Faktoren über alle Sessions")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
            }

            if data.isEmpty {
                Text("Öffne eine Session und füge Limitierungen hinzu.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                Chart(data) { item in
                    BarMark(
                        x: .value("Anzahl", item.count),
                        y: .value("Faktor", item.label)
                    )
                    .cornerRadius(6)
                    .foregroundStyle(Theme.accentGradient)
                    .annotation(position: .trailing) {
                        Text("\(item.count)×")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine().foregroundStyle(Theme.surfaceStroke.opacity(0.5))
                        AxisValueLabel().foregroundStyle(Theme.textTertiary)
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .frame(height: CGFloat(data.count) * 44 + 8)
            }
        }
        .card()
    }
}

#Preview {
    LimiterFrequencyView(sessions: MockData.makeSessions())
        .padding()
        .background(Theme.bg)
}
