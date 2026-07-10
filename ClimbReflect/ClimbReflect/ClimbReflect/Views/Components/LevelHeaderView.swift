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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                tile(title: "Höchster Send", best: send, showStyleBadge: false)
                tile(title: flash == nil ? "Flash" : flashTitle,
                     best: flash, showStyleBadge: discipline == .rope)
            }
            if let comfortGrade {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.accent)
                    Text("Wohlfühl-Grad ")
                        .foregroundStyle(Theme.textSecondary)
                    + Text(comfortGrade).foregroundStyle(Theme.textPrimary).bold()
                }
                .font(.subheadline)
            } else if let comfortCandidate {
                // Endowed Progress: die n/5-Schwelle als sichtbares Mini-Ziel,
                // nur Stichprobe, keine Quote (S32).
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                    Text("Wohlfühl-Grad ab \(ProgressEngine.minSampleSize) Begehungen je Grad — \(comfortCandidate.grade): \(comfortCandidate.sample)/\(ProgressEngine.minSampleSize)")
                        .foregroundStyle(Theme.textTertiary)
                }
                .font(.caption)
            }
            if let nextGrade {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.forward.circle")
                        .font(.caption)
                        .foregroundStyle(Theme.accent2)
                    Text("Nächste Stufe ")
                        .foregroundStyle(Theme.textSecondary)
                    + Text(nextGrade).foregroundStyle(Theme.textPrimary).bold()
                    + Text(nextGradeSuffix).foregroundStyle(Theme.textTertiary)
                }
                .font(.subheadline)
            }
        }
    }

    /// „ · N Begehungen" bzw. „ · noch unversucht" – kein Fortschrittsbalken
    /// (der würde eine Quote suggerieren, S32).
    private var nextGradeSuffix: String {
        guard nextGradeTries > 0 else { return " · noch unversucht" }
        return " · \(nextGradeTries) Begehung\(nextGradeTries == 1 ? "" : "en")"
    }

    private var flashTitle: String {
        discipline == .rope ? "Flash / Onsight" : "Flash"
    }

    private func tile(title: String, best: ProgressEngine.PersonalBest?,
                      showStyleBadge: Bool) -> some View {
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
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.bgElevated))
    }
}
