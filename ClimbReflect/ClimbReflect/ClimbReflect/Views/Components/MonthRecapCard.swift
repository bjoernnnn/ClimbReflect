import SwiftUI

/// „Dein <Monat>" auf „Heute" (MO-13): einmal pro Monat ein faktenbasierter
/// Rückblick auf den Vormonat, dann Ruhe (Fresh-Start-/Peak-End-Effekt).
/// Erscheint nie bei leerem Vormonat, genau einmal, ohne Share/Notification.
/// Kein Chart, keine Partikel – das Gold sitzt nur im Icon (Feier-Monopol
/// bleibt bei TODO11/ER-5, S33).
struct MonthRecapCard: View {
    let recap: ProgressEngine.MonthRecap
    var onDismiss: (() -> Void)? = nil   // FS-5: im Fortschritt-Tab dauerhaft ohne Dismiss

    private var monthName: String {
        recap.month.formatted(.dateTime.month(.wide))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Theme.accent.opacity(0.12)).frame(width: 36, height: 36)
                    Image(systemName: "calendar")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                }
                Text("Dein \(monthName)")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                if let onDismiss {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Monatsrückblick schließen")
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                disciplineRow("Bouldern", recap.boulder)
                disciplineRow("Seil", recap.rope)
            }
            .accessibilityElement(children: .combine)

            // Optionaler Nachtrag (nur nach Umsetzung von TODO11/ER-2): Anzahl der
            // im Vormonat freigeschalteten Erfolge aus einem AchievementUnlock-Fetch.
            // Bewusst deaktiviert vorbereitet – nicht aktivieren, bis das
            // Erfolgssystem existiert.
            // if unlockCount > 0 {
            //     Text("\(unlockCount) Erfolge freigeschaltet")
            //         .font(.subheadline).foregroundStyle(Theme.accent)
            // }
        }
        .card()
    }

    @ViewBuilder
    private func disciplineRow(_ name: String,
                               _ d: ProgressEngine.MonthRecap.DisciplineRecap) -> some View {
        if d.climbDays > 0 {
            let hardest = d.hardestGrade.map { " · härtester \($0)" } ?? ""
            (Text("\(name) — \(d.climbDays) Tage · \(d.sends) Tops\(hardest)")
                .foregroundStyle(Theme.textSecondary)
             + firstSendText(d.firstSendCount))
                .font(.subheadline)
        }
    }

    private func firstSendText(_ count: Int) -> Text {
        guard count > 0 else { return Text("") }
        return Text(" · \(count) Grade erstmals").foregroundStyle(Theme.accent)
    }
}
