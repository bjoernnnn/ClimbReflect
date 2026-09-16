import SwiftUI

/// FS-2: Ein Zeilen-Format für Meilensteine – ersetzt vier verschiedene
/// Ad-hoc-Darstellungen (Heute, Fortschritt-Header, Erfolge, Projekt-Detail).
struct MilestoneRow: View {
    let icon: String
    let title: String
    let value: String
    let detail: String
    let current: Int?
    let target: Int?

    init(icon: String, title: String, value: String, detail: String, current: Int? = nil, target: Int? = nil) {
        self.icon = icon
        self.title = title
        self.value = value
        self.detail = detail
        self.current = current
        self.target = target
    }

    /// Aus einem ProgressEngine.Milestone (Nächste Stufe / Wohlfühl-Grad).
    init(_ milestone: ProgressEngine.Milestone) {
        self.init(
            icon: milestone.kind == .nextGrade ? "arrow.up.forward" : "checkmark.seal",
            title: milestone.title,
            value: milestone.value,
            detail: milestone.detail,
            current: milestone.current,
            target: milestone.target
        )
    }

    /// Aus einem Erfolg „in Reichweite".
    init(achievement data: AchievementViewData) {
        let remaining = data.progress?.remainingText ?? ""
        let detail = remaining.hasPrefix("Noch ")
            ? "noch " + remaining.dropFirst("Noch ".count)
            : remaining
        self.init(
            icon: data.definition.symbol,
            title: "Erfolg",
            value: data.definition.title,
            detail: detail,
            current: data.progress?.current,
            target: data.progress?.target
        )
    }

    var body: some View {
        HStack(spacing: 12) {
            if let current, let target {
                ProgressRing(current: current, target: target)
            } else {
                Circle()
                    .fill(Theme.surfaceRaised)
                    .frame(width: 28, height: 28)
                    .overlay {
                        Image(systemName: icon)
                            .font(.caption)
                            .foregroundStyle(Theme.accent)
                    }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.Typo.label)
                    .foregroundStyle(Theme.textSecondary)
                Text(value)
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                    .monospacedDigit()
            }
            Spacer()
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(spacing: 14) {
        MilestoneRow(icon: "arrow.up.forward", title: "Nächste Stufe", value: "7A", detail: "2 Begehungen")
        MilestoneRow(icon: "checkmark.seal", title: "Wohlfühl-Grad", value: "6B", detail: "noch 2", current: 3, target: 5)
    }
    .padding()
    .background(Theme.bg)
}
