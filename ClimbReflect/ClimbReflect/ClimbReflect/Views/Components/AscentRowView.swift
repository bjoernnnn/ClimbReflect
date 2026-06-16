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
                HStack(spacing: 8) {
                    if ascent.attempts > 1 || ascent.result != .top {
                        Text(ascent.result == .top
                             ? "\(ascent.attempts) Versuche bis zum Top"
                             : "\(ascent.attempts) Versuch\(ascent.attempts == 1 ? "" : "e")")
                            .foregroundStyle(Theme.textSecondary)
                    }
                    if ascent.altitudeGain >= 1 {
                        Label(String(format: "%.0f m", ascent.altitudeGain),
                              systemImage: "arrow.up.right")
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                .font(.caption)
            }

            Spacer()

            HStack(spacing: 6) {
                // P3.11: Foto-Thumbnail falls vorhanden
                if let data = ascent.photoData, let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 36, height: 36)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                Text(ascent.result.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ascent.result.color)
            }
        }
        .padding(.vertical, 4)
    }
}
