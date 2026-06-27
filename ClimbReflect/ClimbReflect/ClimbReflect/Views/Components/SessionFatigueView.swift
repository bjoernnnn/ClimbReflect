import SwiftUI
import SwiftData
import Charts

struct SessionFatigueView: View {
    let session: ClimbSession

    private var points: [StatsEngine.TimelinePoint] {
        StatsEngine.sessionTimeline(session)
    }

    var body: some View {
        if points.count >= 3 {
            VStack(alignment: .leading, spacing: 10) {
                Text("Session-Verlauf")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)

                Chart(points) { p in
                    AreaMark(x: .value("Versuch", p.index),
                             yStart: .value("Basis", 0),
                             yEnd: .value("Send-Rate", p.cumulativeSendRate))
                        .interpolationMethod(.monotone)
                        .foregroundStyle(Theme.accent.opacity(0.1))
                    LineMark(x: .value("Versuch", p.index),
                             y: .value("Send-Rate", p.cumulativeSendRate))
                        .interpolationMethod(.monotone)
                        .foregroundStyle(Theme.accentGradient)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    if p.isTop {
                        PointMark(x: .value("Versuch", p.index),
                                  y: .value("Send-Rate", p.cumulativeSendRate))
                            .foregroundStyle(Theme.accent)
                            .symbolSize(30)
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
                    AxisMarks(values: .automatic(desiredCount: 5)) { v in
                        AxisValueLabel().foregroundStyle(Theme.textTertiary)
                    }
                }
                .frame(height: 80)

                Text("Kumulierte Send-Rate über \(points.count) Versuche")
                    .font(.caption2)
                    .foregroundStyle(Theme.textTertiary)
            }
            .card()
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: ClimbSession.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let session = MockData.makeSessions()[0]
    container.mainContext.insert(session)
    return SessionFatigueView(session: session)
        .padding()
        .background(Theme.bg)
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
