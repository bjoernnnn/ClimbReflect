import SwiftUI

/// FS-4: zeigt Fortschritt (härtester Top) statt Aufwand (Dauer/RPE) – das
/// zählt für das Fortschrittsgefühl mehr als die reine Belastung (S31).
struct SessionRow: View {
    let session: ClimbSession
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var tops: [Ascent] { session.ascents.filter { $0.result == .top } }
    private var hardestTop: Ascent? { ProgressEngine.hardest(tops.filter(\.isGraded)) }

    // AX-1: bei sehr großer Schrift HStack -> VStack, damit nichts abgeschnitten wird.
    private var layout: AnyLayout {
        dynamicTypeSize >= .accessibility1
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 14))
    }

    var body: some View {
        layout {
            IconTile(symbol: session.sessionType.symbol, tint: Theme.accent, size: 40)
                .overlay(alignment: .topTrailing) {
                    if !session.reflectionCompleted && session.isClimbing {
                        Circle()
                            .fill(Theme.accent)
                            .frame(width: 8, height: 8)
                            .offset(x: 3, y: -3)
                    }
                }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 0) {
                    Text(session.sessionType.label)
                    if session.outdoor {
                        Text(" · Outdoor")
                    } else if let gym = session.gymName, !gym.isEmpty {
                        Text(" · \(gym)")
                    }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)

                HStack(spacing: 0) {
                    Text(session.date.formatted(.dateTime.weekday(.abbreviated).day().month(.twoDigits)))
                    if session.isClimbing && !tops.isEmpty {
                        Text(" · \(tops.count) Top\(tops.count == 1 ? "" : "s")")
                    }
                    Text(" · \(session.durationMinutes) Min")
                }
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
            }

            Spacer()

            if let hardestTop {
                Text(GradeConverter.display(grade: hardestTop.gradeRaw, storedIn: hardestTop.gradeSystem))
                    .font(Theme.Typo.metric)
                    .foregroundStyle(Theme.textPrimary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                .fill(Theme.surface.opacity(0.75))
        )
        .accessibilityElement(children: .combine)
    }
}
