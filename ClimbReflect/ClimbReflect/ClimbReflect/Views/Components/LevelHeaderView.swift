import SwiftUI

/// Level-Block des Fortschritt-Tabs: zwei Bestleistungs-Kacheln (Send + Flash)
/// plus Wohlfühl-Grad-Zeile. Die PB-Kacheln zeigen die gesamte Historie und
/// ignorieren bewusst den Zeitraum-Picker (Konzept ①).
struct LevelHeaderView: View {
    let send: ProgressEngine.PersonalBest?
    let flash: ProgressEngine.PersonalBest?
    let comfortGrade: String?
    let discipline: ProgressEngine.Discipline

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
            }
        }
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
