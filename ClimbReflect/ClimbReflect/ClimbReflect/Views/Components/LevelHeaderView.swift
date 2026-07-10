import SwiftUI

/// Level-Block des Fortschritt-Tabs: zwei Bestleistungs-Kacheln (Send + Flash)
/// plus Wohlfühl-Grad-Zeile. Die PB-Kacheln zeigen die gesamte Historie und
/// ignorieren bewusst den Zeitraum-Picker (Konzept ①).
struct LevelHeaderView: View {
    let send: ProgressEngine.PersonalBest?
    let flash: ProgressEngine.PersonalBest?
    let comfortGrade: String?
    let discipline: ProgressEngine.Discipline
    // MO-8: nächste Leiterstufe über dem historischen Höchst-Send (Goal-Gradient).
    var nextGrade: String? = nil
    var nextGradeTries: Int = 0
    // MO-9: Wohlfühl-Grad-Kandidat (nur relevant, solange comfortGrade nil ist).
    var comfortCandidate: (grade: String, sample: Int)? = nil
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
                tile(title: "Höchster Send", best: send, showStyleBadge: false,
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

    // MARK: - DS-3: Fakten-Karte (Wohlfühl-Grad · Nächste Stufe · Erstmals gesendet)

    private struct FactRow: Identifiable {
        let id: String   // Label, eindeutig innerhalb einer Karte
        let icon: String
        let iconColor: Color
        let label: String
        let value: String
    }

    /// true, solange die Wohlfühl-Zeile den Kandidat-Zweig zeigt (steuert die
    /// Fußnote unter der Karte).
    private var showsComfortCandidateFootnote: Bool {
        comfortGrade == nil && comfortCandidate != nil
    }

    private var factRows: [FactRow] {
        var rows: [FactRow] = []
        if let comfortGrade {
            rows.append(FactRow(id: "comfort", icon: "checkmark.seal.fill", iconColor: Theme.accent,
                                label: "Wohlfühl-Grad", value: comfortGrade))
        } else if let comfortCandidate {
            // Endowed Progress: die n/5-Schwelle als sichtbares Mini-Ziel, nur
            // Stichprobe, keine Quote (S32) — gedimmtes Icon signalisiert „noch
            // keine Aussage".
            rows.append(FactRow(id: "comfort", icon: "checkmark.seal", iconColor: Theme.textTertiary,
                                label: "Wohlfühl-Grad",
                                value: "\(comfortCandidate.grade) · \(comfortCandidate.sample)/\(ProgressEngine.minSampleSize)"))
        }
        if let nextGrade {
            rows.append(FactRow(id: "next", icon: "arrow.up.forward", iconColor: Theme.accent,
                                label: "Nächste Stufe", value: "\(nextGrade) · \(nextGradeShort)"))
        }
        if !firstSends.isEmpty {
            rows.append(FactRow(id: "firstSends", icon: "sparkles", iconColor: Theme.accent,
                                label: "Erstmals gesendet", value: firstSendsValue))
        }
        return rows
    }

    /// „N Begehungen" bzw. „unversucht" – Kurzform ohne „noch", kein
    /// Fortschrittsbalken (der würde eine Quote suggerieren, S32).
    private var nextGradeShort: String {
        guard nextGradeTries > 0 else { return "unversucht" }
        return "\(nextGradeTries) Begehung\(nextGradeTries == 1 ? "" : "en")"
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
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        HStack(spacing: 10) {
                            Image(systemName: row.icon)
                                .font(.caption)
                                .foregroundStyle(row.iconColor)
                                .frame(width: 22)
                            Text(row.label)
                                .font(.subheadline)
                                .foregroundStyle(Theme.textSecondary)
                            Spacer()
                            Text(row.value)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .padding(.vertical, 10)
                        if index < rows.count - 1 {
                            Divider().overlay(Theme.surfaceStroke)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .background(RoundedRectangle(cornerRadius: 16).fill(Theme.bgElevated))

                if showsComfortCandidateFootnote {
                    Text("Wohlfühl-Grad ab \(ProgressEngine.minSampleSize) Begehungen je Grad")
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
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.textTertiary)
            if let best {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(best.grade)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
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
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
                Text("Noch keine Begehung")
                    .font(.caption2)
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.bgElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
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
