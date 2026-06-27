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
                    Text(GradeConverter.display(grade: ascent.gradeRaw, storedIn: ascent.gradeSystem))
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
                    if let dur = ascent.durationSeconds, dur > 0 {
                        Label(formatDuration(dur), systemImage: "timer")
                            .foregroundStyle(Theme.textTertiary)
                    }
                    if ascent.altitudeGain >= 1 {
                        Label(String(format: "%.0f m", ascent.altitudeGain),
                              systemImage: "arrow.up.right")
                            .foregroundStyle(Theme.textTertiary)
                    }
                    if let project = ascent.project {
                        HStack(spacing: 3) {
                            Image(systemName: "target")
                            Text(project.name)
                        }
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Theme.accent.opacity(0.12)))
                    }
                    // SH-10: Schuh-Label
                    if let shoeName = ascent.shoe?.name ?? ascent.shoeName {
                        HStack(spacing: 3) {
                            Image(systemName: "shoeprints.fill")
                            Text(shoeName)
                        }
                        .foregroundStyle(Theme.accent2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Theme.accent2.opacity(0.12)))
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

    private func formatDuration(_ t: Double) -> String {
        let s = Int(t)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
