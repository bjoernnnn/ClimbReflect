import SwiftUI

/// Level-Block des Fortschritt-Tabs: zwei Bestleistungs-Kacheln (Send + Flash)
/// plus Wohlfühl-Grad-Zeile. Die PB-Kacheln zeigen die gesamte Historie und
/// ignorieren bewusst den Zeitraum-Picker (Konzept ①).
struct LevelHeaderView: View {
    let send: ProgressEngine.PersonalBest?
    let flash: ProgressEngine.PersonalBest?
    let comfortGrade: String?
    let discipline: ProgressEngine.Discipline
    // FS-5: nächste Leiterstufe (Goal-Gradient) + Wohlfühl-Grad-Kandidat kommen
    // beide aus der gemeinsamen Meilenstein-Engine (FortschrittView reicht sie herein).
    var milestones: [ProgressEngine.Milestone] = []
    // DS-2: PB-Feier wandert in die Send-Kachel selbst (Gold-Stroke + NEU-Badge)
    // statt einer separaten Chip-Zeile darüber — „Neuigkeit wohnt in den
    // Elementen, nicht über ihnen".
    var celebratesSend: Bool = false
    // DS-3: Erst-Sends des Zeitraums (bereits absteigend nach order, MO-2);
    // leer bei „Alles" (periodHighlights liefert dort ohnehin [] zurück).
    var firstSends: [ProgressEngine.FirstSend] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                tile(title: "Höchster Top", best: send, showStyleBadge: false,
                     celebrates: celebratesSend)
                tile(title: flash == nil ? "Flash" : flashTitle,
                     best: flash, showStyleBadge: discipline == .rope)
            }
            factCard
        }
    }

    private var flashTitle: String {
        discipline == .rope ? "Flash / Onsight" : "Flash"
    }

    // MARK: - FS-5: Fakten-Karte (Wohlfühl-Grad · Nächste Stufe · Erste Tops) über MilestoneRow

    /// true, solange die Wohlfühl-Zeile den Kandidat-Zweig zeigt (steuert die
    /// Fußnote unter der Karte).
    private var showsComfortCandidateFootnote: Bool {
        comfortGrade == nil && milestones.contains { $0.kind == .comfortGrade }
    }

    private var factRows: [(id: String, row: MilestoneRow)] {
        var rows: [(id: String, row: MilestoneRow)] = []
        if let comfortGrade {
            rows.append(("comfort", MilestoneRow(icon: "checkmark.seal.fill", title: "Wohlfühl-Grad",
                                                  value: comfortGrade, detail: "", current: nil, target: nil)))
        }
        for milestone in milestones {
            rows.append((milestone.kind == .nextGrade ? "next" : "comfort", MilestoneRow(milestone)))
        }
        if !firstSends.isEmpty {
            rows.append(("firstSends", MilestoneRow(icon: "sparkles", title: "Erste Tops",
                                                     value: firstSendsValue, detail: "", current: nil, target: nil)))
        }
        return rows
    }

    /// Max. 3 Grade (bereits absteigend nach order), Überhang als „ +N".
    private var firstSendsValue: String {
        let shown = firstSends.prefix(3)
        let text = shown.map(\.grade).joined(separator: " · ")
        let overflow = firstSends.count - shown.count
        return overflow > 0 ? "\(text) +\(overflow)" : text
    }

    @ViewBuilder
    private var factCard: some View {
        let rows = factRows
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, entry in
                        entry.row
                            .padding(.vertical, 10)
                        if index < rows.count - 1 {
                            Divider().overlay(Theme.separator)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous).fill(Theme.surfaceRaised))

                if showsComfortCandidateFootnote {
                    Text("Wohlfühl-Grad wird ab \(ProgressEngine.minSampleSize) Begehungen in einem Grad eingeschätzt.")
                        .font(.caption2)
                        .foregroundStyle(Theme.textTertiary)
                        .padding(.horizontal, 4)
                }
            }
        }
    }

    private func tile(title: String, best: ProgressEngine.PersonalBest?,
                      showStyleBadge: Bool, celebrates: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(Theme.Typo.label)
                .foregroundStyle(Theme.textSecondary)
            if let best {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(best.grade)
                        .font(Theme.Typo.metricHero)
                        .foregroundStyle(Theme.textPrimary)
                        .monospacedDigit()
                    if showStyleBadge, let style = best.style {
                        Text(style.label)
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(Theme.accent.opacity(0.2)))
                            .foregroundStyle(Theme.accent)
                    }
                }
                Text(best.date.formatted(.dateTime.month(.abbreviated).year()))
                    .font(.caption2)
                    .foregroundStyle(Theme.textTertiary)
            } else {
                Text("—")
                    .font(Theme.Typo.metricHero)
                    .foregroundStyle(Theme.textTertiary)
                Text("Noch keine Begehung")
                    .font(.caption2)
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.medium)
                .fill(Theme.surfaceRaised)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.medium)
                        .stroke(celebrates ? Theme.gold.opacity(0.35) : Color.clear, lineWidth: 1)
                )
        )
        .overlay(alignment: .topTrailing) {
            if celebrates {
                Text("NEU")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Theme.bg)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(Theme.goldGradient))
                    .padding(10)
            }
        }
    }
}
