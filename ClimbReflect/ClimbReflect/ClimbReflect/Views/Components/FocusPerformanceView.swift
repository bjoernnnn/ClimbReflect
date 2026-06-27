import SwiftUI
import Charts

struct FocusPerformanceView: View {
    let sessions: [ClimbSession]

    private var data: [StatsEngine.FocusPerf] { StatsEngine.focusVsPerformance(sessions) }

    private func label(_ r: Int) -> String {
        switch r {
        case 1: return "Abgelenkt"
        case 2: return "Wenig"
        case 3: return "Okay"
        case 4: return "Fokussiert"
        default: return "Im Flow"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Fokus & Leistung")
                    .font(.headline).foregroundStyle(Theme.textPrimary)
                Text("Send-Rate nach Fokus-Bewertung")
                    .font(.caption).foregroundStyle(Theme.textSecondary)
            }

            if data.count < 2 {
                Text("Bewerte den Fokus in mindestens 2 verschiedenen Sessions um diesen Chart zu sehen.")
                    .font(.subheadline).foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                Chart(data) { p in
                    BarMark(x: .value("Fokus", label(p.focusRating)),
                            y: .value("Send-Rate", p.avgSendRate))
                        .foregroundStyle(Theme.accent.opacity(0.75))
                        .cornerRadius(4)
                        .annotation(position: .top) {
                            Text("\(Int(p.avgSendRate * 100))%")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(Theme.textSecondary)
                        }
                }
                .chartYScale(domain: 0...1)
                .chartYAxis {
                    AxisMarks(values: [0.0, 0.5, 1.0]) { v in
                        AxisGridLine().foregroundStyle(Theme.surfaceStroke.opacity(0.5))
                        AxisValueLabel {
                            if let d = v.as(Double.self) {
                                Text("\(Int(d * 100))%").font(.caption2).foregroundStyle(Theme.textTertiary)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { v in
                        AxisValueLabel().foregroundStyle(Theme.textTertiary)
                    }
                }
                .frame(height: 120)

                Text("★ = dein Fokus-Rating in der Reflexion · Punkte = Anzahl Sessions")
                    .font(.caption2).foregroundStyle(Theme.textTertiary)
            }
        }
        .card()
    }
}

#Preview {
    FocusPerformanceView(sessions: MockData.makeSessions())
        .padding()
        .background(Theme.bg)
}
