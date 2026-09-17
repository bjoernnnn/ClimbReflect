import SwiftUI

/// PG-5: aus SessionDetailView ausgelagert (reiner Refactor, keine
/// Verhaltensänderung) – Vitalwerte, Zeit-Donut, Metrik-Kacheln (SI-2/SI-3).
struct SessionInsightsSection: View {
    @Bindable var session: ClimbSession

    private let ropeTypes: [SessionType] = [.lead, .topRope, .autoBelay]
    private let twoColumns = [GridItem(.flexible()), GridItem(.flexible())]

    // PG-6: Gate für den Aufrufer, ob der ganze „Messwerte"-Block überhaupt etwas zeigt.
    var hasContent: Bool {
        let showAlt = ropeTypes.contains(session.sessionType) && session.altitudeTotalGain > 0
        if session.avgHeartRate != nil || session.activeEnergyKcal != nil || showAlt { return true }
        guard session.isClimbing else { return false }
        let insights = StatsEngine.insights(for: session)
        return insights.hasFullTimeCoverage || insights.hasAttemptTimes || session.durationSeconds > 0
    }

    var body: some View {
        let showAlt = ropeTypes.contains(session.sessionType) && session.altitudeTotalGain > 0
        if session.avgHeartRate != nil || session.activeEnergyKcal != nil || showAlt {
            healthCard
        }
        insightsSection
    }

    // MARK: - Session-Insights (SI-2 / SI-3)

    @ViewBuilder
    private var insightsSection: some View {
        let insights = StatsEngine.insights(for: session)
        if session.isClimbing {
            if insights.hasFullTimeCoverage {
                SessionTimeDonut(insights: insights)
                insightsMetrics(insights: insights)
            } else if insights.hasAttemptTimes {
                // FB-10: nur Teil-Abdeckung → Donut verzerrt (ungetimte Ascents = Pause) → ausblenden
                Text("Aktivzeit aus \(insights.timedAscentCount) von \(insights.ascentCount) Versuchen erfasst — Zeitaufteilung dafür ausgeblendet.")
                    .font(.caption).foregroundStyle(Theme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()
                insightsMetrics(insights: insights)
            } else if session.durationSeconds > 0 {
                Text("Zur Zeitaufteilung gibt es für diese Session keine Daten – Aktivzeit wird nur bei Watch-Sessions mit Start/Stopp pro Versuch gemessen.")
                    .font(.caption).foregroundStyle(Theme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()
                insightsMetrics(insights: insights)
            }
        }
    }

    @ViewBuilder
    private func insightsMetrics(insights: StatsEngine.SessionInsights) -> some View {
        let items: [(label: String, value: String, symbol: String, color: Color)?] = [
            insights.hasAttemptTimes ? ("Aktivzeit (erfasst)",
                formatMinutes(insights.activeSeconds),
                "figure.climbing", Theme.accent) : nil,
            insights.avgAttemptSeconds.map { ("Ø Versuch",
                formatSeconds($0), "timer", Theme.accent2) },
            (insights.ascentCount >= ProgressEngine.minSampleSize ? insights.successRate : nil).map {
                ("Erfolgsquote", "\(Int($0 * 100)) % · n=\(insights.ascentCount)", "percent", Theme.textSecondary)
            },
            insights.hardestTopGrade.map { ("Top-Grad",
                GradeConverter.display(grade: $0, storedIn: insights.hardestTopGradeSystem ?? .fontainebleau),
                "trophy", Theme.accent) },   // RP-17/KR-9: Gold nur für tatsächlich Erreichtes (E19)
        ]
        let valid = items.compactMap { $0 }
        if !valid.isEmpty {
            let cols = valid.count >= 4
                ? [GridItem(.flexible()), GridItem(.flexible())]
                : [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
            VStack(alignment: .leading, spacing: 14) {
                LazyVGrid(columns: cols, spacing: 10) {
                    ForEach(Array(valid.enumerated()), id: \.offset) { _, item in
                        metricTile(item.label, value: item.value, symbol: item.symbol, color: item.color)
                    }
                }
            }
            .card()
        }
    }

    private func formatMinutes(_ seconds: Double) -> String {
        Duration.seconds(seconds).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }

    private func formatSeconds(_ t: Double) -> String {
        let s = Int(t)
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    // MARK: - Vitalwerte

    private var healthCard: some View {
        let showAlt = ropeTypes.contains(session.sessionType) && session.altitudeTotalGain > 0
        let metricCount = (session.avgHeartRate != nil ? 1 : 0)
            + (session.maxHeartRate != nil ? 1 : 0)
            + (session.activeEnergyKcal != nil ? 1 : 0)
            + (showAlt ? 1 : 0)
        return VStack(alignment: .leading, spacing: 14) {
            Label("Vitalwerte", systemImage: "heart.fill")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)

            if metricCount >= 4 {
                LazyVGrid(columns: twoColumns, spacing: 10) {
                    metricsContent(showAlt: showAlt)
                }
            } else {
                HStack(spacing: 10) {
                    metricsContent(showAlt: showAlt)
                }
            }
        }
        .card()
    }

    @ViewBuilder
    private func metricsContent(showAlt: Bool) -> some View {
        if let avg = session.avgHeartRate {
            metricTile("Ø HF", value: "\(Int(avg)) bpm",
                       symbol: "heart.fill", color: Theme.danger)
        }
        if let max = session.maxHeartRate {
            metricTile("Max HF", value: "\(Int(max)) bpm",
                       symbol: "heart.fill", color: Theme.danger.opacity(0.7))
        }
        if let kcal = session.activeEnergyKcal {
            metricTile("Energie", value: "\(Int(kcal)) kcal",
                       symbol: "flame.fill", color: Theme.accent)
        }
        if showAlt {
            metricTile("Höhenmeter", value: "\(Int(session.altitudeTotalGain)) m",
                       symbol: "arrow.up.forward", color: Theme.accent)
        }
    }

    private func metricTile(_ label: String, value: String, symbol: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol)
                .foregroundStyle(color)
                .font(.body)
            // lineLimit(1) + Skalierung: kein Umbruch → alle Kacheln einer Reihe gleich hoch
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle.theme(Theme.Radius.medium).fill(Theme.surfaceRaised))
    }
}
