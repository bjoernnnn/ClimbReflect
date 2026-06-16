import SwiftUI

struct AscentRowView: View {
    let ascent: Ascent

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: ascent.result.symbol)
                .foregroundStyle(ascent.result.color)
                .font(.system(size: 20))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(ascent.gradeRaw)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(ascent.gradeSystem.label)
                        .font(.caption2)
                        .foregroundStyle(Theme.textTertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Theme.bgElevated))
                    if let style = ascent.style {
                        HStack(spacing: 3) {
                            Image(systemName: style.symbol)
                            Text(style.label)
                        }
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.gold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Theme.gold.opacity(0.12)))
                    }
                }
                if ascent.attempts > 1 || ascent.result != .top {
                    Text(ascent.result == .top
                         ? "\(ascent.attempts) Versuche bis zum Top"
                         : "\(ascent.attempts) Versuch\(ascent.attempts == 1 ? "" : "e")")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            Spacer()

            Text(ascent.result.label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(ascent.result.color)
        }
        .padding(.vertical, 4)
    }
}
