import SwiftUI
import Charts

struct FingerStrengthTrendView: View {
    let sessions: [ClimbSession]

    private var data: [StatsEngine.StrengthPoint] {
        StatsEngine.fingerStrengthTrend(sessions)
    }

    private var edgeSizes: [Int] {
        Array(Set(data.map(\.edgeMM))).sorted()
    }

    private func color(for edgeMM: Int) -> Color {
        let sizes = edgeSizes
        let idx = sizes.firstIndex(of: edgeMM) ?? 0
        let colors: [Color] = [Theme.accent, Theme.gold, Theme.accent2, Theme.danger]
        return colors[idx % colors.count]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Fingerkraft-Trend")
                    .font(.headline).foregroundStyle(Theme.textPrimary)
                Text("Hangboard Max-Hang nach Leistengröße")
                    .font(.caption).foregroundStyle(Theme.textSecondary)
            }

            if data.isEmpty {
                Text("Erfasse Hangboard-Sets in Training-Sessions um diesen Chart zu sehen.")
                    .font(.subheadline).foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                Chart {
                    ForEach(data) { p in
                        LineMark(
                            x: .value("Datum", p.date),
                            y: .value("Kg", p.totalWeightKg),
                            series: .value("Leiste", "\(p.edgeMM) mm")
                        )
                        .foregroundStyle(color(for: p.edgeMM))
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Datum", p.date),
                            y: .value("Kg", p.totalWeightKg)
                        )
                        .foregroundStyle(color(for: p.edgeMM))
                        .symbolSize(30)
                    }
                }
                .chartYAxis {
                    AxisMarks { v in
                        AxisGridLine().foregroundStyle(Theme.surfaceStroke.opacity(0.4))
                        AxisValueLabel {
                            if let d = v.as(Double.self) {
                                Text("\(Int(d)) kg").font(.caption2).foregroundStyle(Theme.textTertiary)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { _ in
                        AxisGridLine().foregroundStyle(Theme.surfaceStroke.opacity(0.3))
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                .frame(height: 160)

                if edgeSizes.count > 1 {
                    HStack(spacing: 12) {
                        ForEach(edgeSizes, id: \.self) { mm in
                            Label("\(mm) mm", systemImage: "rectangle.fill")
                                .font(.caption2)
                                .foregroundStyle(color(for: mm))
                        }
                    }
                }

                Text("Gesamtgewicht = Körpergewicht + Zusatzgewicht · je Leistengröße eine Linie")
                    .font(.caption2).foregroundStyle(Theme.textTertiary)
            }
        }
        .card()
    }
}

#Preview {
    FingerStrengthTrendView(sessions: [])
        .padding()
        .background(Theme.bg)
}
