import SwiftUI

/// PG-6/E25: ersetzt SessionHeaderRow – zeigt zuerst, was geklettert wurde
/// (härtester Top, Tops, Dauer), nicht nur Metadaten. Kein Kartenhintergrund,
/// steht direkt auf Theme.bg (Apple-Fitness-Stil).
struct SessionSummaryHeader: View {
    @Bindable var session: ClimbSession
    @State private var showLocationEditor = false

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "EEEE, dd. MMMM yyyy · HH:mm"
        return f
    }()

    private var tops: [Ascent] { session.ascents.filter { $0.result == .top } }
    private var hardestTop: Ascent? { ProgressEngine.hardest(tops.filter(\.isGraded)) }

    private var locationText: String? {
        if session.outdoor { return "Outdoor" }
        if let gym = session.gymName, !gym.isEmpty { return gym }
        return nil
    }

    private var sourceLabel: String? {
        switch session.source {
        case .watch:     "Apple Watch"
        case .healthKit: "Apple Health"
        case .manual:    nil
        }
    }

    private var subtitle: String {
        [locationText, sourceLabel].compactMap { $0 }.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow
            if session.isClimbing && !session.ascents.isEmpty {
                metricsRow
            }
        }
        .sheet(isPresented: $showLocationEditor) {
            SessionLocationEditor(session: session)
        }
    }

    private var headerRow: some View {
        HStack(spacing: 16) {
            IconTile(symbol: session.sessionType.symbol, tint: Theme.accent, size: 52)
            VStack(alignment: .leading, spacing: 4) {
                Text(Self.dateFormatter.string(from: session.date))
                    .font(Theme.Typo.label)
                    .foregroundStyle(Theme.textSecondary)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            Spacer()
            // ST-2: Standort-Editor öffnen
            Button {
                showLocationEditor.toggle()
            } label: {
                Image(systemName: "mappin.and.ellipse")
                    .font(.body)
                    .foregroundStyle(session.outdoor || (session.gymName != nil) ? Theme.accent2 : Theme.textTertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Standort bearbeiten")
        }
    }

    private var metricsRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 20) {
            if let hardestTop {
                metricColumn(GradeConverter.display(grade: hardestTop.gradeRaw, storedIn: hardestTop.gradeSystem),
                             label: "Härtester Top", hero: true)
            }
            metricColumn("\(tops.count)", label: "Tops")
            metricColumn(session.durationText, label: "Dauer")
        }
    }

    private func metricColumn(_ value: String, label: String, hero: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(hero ? Theme.Typo.metricHero : Theme.Typo.metric)
                .foregroundStyle(Theme.textPrimary)
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
    }
}
