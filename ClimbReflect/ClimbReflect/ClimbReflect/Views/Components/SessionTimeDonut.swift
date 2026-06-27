import SwiftUI
import Charts

struct SessionTimeDonut: View {
    let insights: StatsEngine.SessionInsights

    private var activeMin: Int { Int(insights.activeSeconds / 60) }
    private var pauseMin: Int  { Int(insights.pauseSeconds / 60) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Zeitaufteilung", systemImage: "chart.pie.fill")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)

            HStack(spacing: 20) {
                Chart {
                    SectorMark(
                        angle: .value("Aktiv", max(insights.activeSeconds, 0.001)),
                        innerRadius: .ratio(0.62),
                        angularInset: 1.5
                    )
                    .foregroundStyle(Theme.accent)
                    .cornerRadius(4)

                    SectorMark(
                        angle: .value("Pause", max(insights.pauseSeconds, 0.001)),
                        innerRadius: .ratio(0.62),
                        angularInset: 1.5
                    )
                    .foregroundStyle(Theme.bgElevated)
                    .cornerRadius(4)
                }
                .chartBackground { _ in
                    Text("\(Int(insights.activeShare * 100))%")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                }
                .frame(width: 90, height: 90)

                VStack(alignment: .leading, spacing: 10) {
                    legendRow(color: Theme.accent, label: "Aktiv geklettert", minutes: activeMin)
                    legendRow(color: Theme.bgElevated.opacity(0.6), label: "Pause", minutes: pauseMin, border: true)
                }
            }
        }
        .card()
    }

    private func legendRow(color: Color, label: String, minutes: Int, border: Bool = false) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .overlay(
                    border ? RoundedRectangle(cornerRadius: 3).strokeBorder(Theme.surfaceStroke, lineWidth: 1) : nil
                )
                .frame(width: 12, height: 12)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                Text("\(minutes) Min")
                    .font(.caption2)
                    .foregroundStyle(Theme.textTertiary)
            }
        }
    }
}

#Preview {
    let insights = StatsEngine.SessionInsights(
        totalSeconds: 5400,
        activeSeconds: 2700,
        hasAttemptTimes: true,
        avgAttemptSeconds: 120,
        longestAttemptSeconds: 240,
        sendsPerHour: 2.0,
        load: 420,
        successRate: 0.6,
        attemptsPerSend: 2.5,
        hardestTopGrade: "7A"
    )
    return SessionTimeDonut(insights: insights)
        .padding()
        .background(Theme.bg)
        .preferredColorScheme(.dark)
}
