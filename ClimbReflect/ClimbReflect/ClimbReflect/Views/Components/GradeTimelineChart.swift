import SwiftUI
import Charts

/// Verlaufs-Chart „Werde ich besser?“ – härtester Send je Monat als Stufenlinie,
/// Flash/Onsight als dezente zweite Serie. Monate ohne Sends bleiben Lücken: die
/// Linie wird pro zusammenhängendem Monatslauf gezeichnet, es wird nie über eine
/// Lücke interpoliert (S32/Konzept ②).
struct GradeTimelineChart: View {
    let points: [ProgressEngine.TimelinePoint]
    let discipline: ProgressEngine.Discipline

    /// Ein Punkt der Linie mit Segment-Zuordnung (Segmentwechsel = Monatslücke).
    private struct Seg: Identifiable {
        let id: Int          // laufender Index (eindeutig für ForEach)
        let segment: Int     // zusammenhängender Lauf
        let month: Date
        let order: Int
    }

    /// Zerlegt month-sortierte (Monat, Grad)-Paare in Segmente: sobald zwei
    /// aufeinanderfolgende Punkte nicht in benachbarten Monaten liegen, beginnt
    /// ein neues Segment – so verbindet keine Linie über eine Lücke hinweg.
    private func segments(_ pairs: [(month: Date, order: Int)]) -> [Seg] {
        let cal = Calendar.current
        var out: [Seg] = []
        var segment = 0
        var prev: Date?
        for (i, p) in pairs.enumerated() {
            if let prev, cal.date(byAdding: .month, value: 1, to: prev) != p.month { segment += 1 }
            out.append(Seg(id: i, segment: segment, month: p.month, order: p.order))
            prev = p.month
        }
        return out
    }

    private var sendSegs: [Seg] {
        segments(points.compactMap { p in p.sendOrder.map { (p.month, $0) } })
    }
    private var flashSegs: [Seg] {
        segments(points.compactMap { p in p.flashOrder.map { (p.month, $0) } })
    }

    private var yTicks: [Int] {
        let orders = points.flatMap { [$0.sendOrder, $0.flashOrder].compactMap { $0 } }
        guard let lo = orders.min(), let hi = orders.max() else { return [] }
        return Array((lo - 1)...(hi + 1))
    }

    private var flashLabel: String { discipline == .rope ? "Flash · Onsight" : "Flash" }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Grad-Verlauf")
                .font(.headline).foregroundStyle(Theme.textPrimary)

            if points.count < 2 {
                Text("Ab zwei Monaten mit Sends erscheint hier dein Verlauf.")
                    .font(.subheadline).foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                chart
                legend
            }
        }
        .card()
    }

    private var chart: some View {
        Chart {
            ForEach(flashSegs) { s in
                LineMark(x: .value("Monat", s.month, unit: .month),
                         y: .value("Grad", s.order),
                         series: .value("Serie", "flash-\(s.segment)"))
                    .foregroundStyle(Theme.accent.opacity(0.7))
                    .interpolationMethod(.stepEnd)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            }
            ForEach(sendSegs) { s in
                LineMark(x: .value("Monat", s.month, unit: .month),
                         y: .value("Grad", s.order),
                         series: .value("Serie", "send-\(s.segment)"))
                    .foregroundStyle(Theme.gold)
                    .interpolationMethod(.stepEnd)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                PointMark(x: .value("Monat", s.month, unit: .month),
                          y: .value("Grad", s.order))
                    .foregroundStyle(Theme.gold)
                    .symbolSize(28)
            }
        }
        .chartYAxis {
            AxisMarks(values: yTicks) { value in
                AxisGridLine().foregroundStyle(Theme.surfaceStroke.opacity(0.4))
                AxisValueLabel {
                    if let order = value.as(Int.self) {
                        Text(ProgressEngine.gradeLabel(forOrder: order, discipline: discipline))
                            .font(.caption2).foregroundStyle(Theme.textTertiary)
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
        .frame(height: 150)
    }

    private var legend: some View {
        HStack(spacing: 14) {
            legendItem(color: Theme.gold, label: "Send")
            legendItem(color: Theme.accent.opacity(0.7), label: flashLabel)
        }
        .font(.caption2).foregroundStyle(Theme.textTertiary)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Capsule().fill(color).frame(width: 14, height: 3)
            Text(label)
        }
    }
}
