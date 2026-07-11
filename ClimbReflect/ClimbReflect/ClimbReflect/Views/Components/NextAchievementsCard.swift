import SwiftUI

/// „Nächster Erfolg"-Karte (ERFOLGE-KONZEPT-V2 · Abschnitt 10, L1). Kompakter
/// Goal-Gradient-Einstieg für den Today-Tab: höchster Fortschritt < 100 %,
/// Mini-Ring + Rest-Text, Tap → Erfolge-Tab. Wiederverwendet in EP-10.
struct NextAchievementsCard: View {
    let data: AchievementViewData

    var body: some View {
        HStack(spacing: 12) {
            AchievementMedallion(symbol: data.definition.symbol,
                                 state: .locked(progress: data.progress?.fraction), size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text("Nächster Erfolg".uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.textTertiary)
                Text(data.definition.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                if let text = data.progress?.remainingText {
                    Text(text)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            Spacer(minLength: 0)
            if let fraction = data.progress?.fraction {
                Text("\(Int((fraction * 100).rounded())) %")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.accent)
                    .monospacedDigit()
            }
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.bgElevated))
    }
}
