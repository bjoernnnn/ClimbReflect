import SwiftUI

// P3.10: Wochen-Recap als teilbare Karte

struct WeeklyRecapView: View {
    let sessions: [ClimbSession]
    @State private var showShare = false
    @State private var shareImage: UIImage?

    private var recap: StatsEngine.WeekRecap {
        StatsEngine.currentWeekRecap(sessions)
    }

    private var weekLabel: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "d. MMM"
        return "\(f.string(from: recap.weekStart)) – \(f.string(from: recap.weekEnd))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Wochenrückblick")
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    Text(weekLabel)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Button {
                    shareRecap()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.accent)
                }
            }

            if recap.sessions == 0 {
                Text("Noch keine Sessions diese Woche.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                RecapCardContent(recap: recap)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.surface))
        .sheet(isPresented: $showShare) {
            if let img = shareImage {
                ShareSheet(items: [img])
            }
        }
    }

    private func shareRecap() {
        let card = RecapCardContent(recap: recap)
            .padding(24)
            .background(Theme.surface)
            .environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: card)
        renderer.scale = UIScreen.main.scale
        shareImage = renderer.uiImage
        showShare = true
    }
}

// MARK: - Karten-Inhalt (auch für ImageRenderer nutzbar)

struct RecapCardContent: View {
    let recap: StatsEngine.WeekRecap

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                recapTile("Tops", value: "\(recap.tops)", symbol: "checkmark.circle.fill",
                          color: Theme.accent)
                recapTile("Sessions", value: "\(recap.sessions)", symbol: "figure.climbing",
                          color: Theme.textSecondary)
                recapTile("Minuten", value: "\(recap.minutes)", symbol: "clock.fill",
                          color: Theme.textSecondary)
                if let rpe = recap.avgRPE {
                    recapTile("Ø RPE", value: String(format: "%.1f", rpe),
                              symbol: "gauge.with.dots.needle.67percent",
                              color: rpeColor(rpe))
                }
            }

            if let grade = recap.highestGrade, let sys = recap.highestGradeSystem {
                HStack(spacing: 8) {
                    Image(systemName: recap.newPB ? "trophy.fill" : "chart.bar.fill")
                        .foregroundStyle(recap.newPB ? Theme.gold : Theme.accent)
                    Text(recap.newPB
                         ? "Neuer Höchstgrad: \(grade) (\(sys.label))"
                         : "Schwerstes Top: \(grade) (\(sys.label))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(recap.newPB ? Theme.gold : Theme.textPrimary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 10)
                    .fill(recap.newPB ? Theme.gold.opacity(0.12) : Theme.bgElevated))
            }

            Text("ClimbReflect · Wochenrückblick")
                .font(.system(size: 10))
                .foregroundStyle(Theme.textTertiary)
        }
    }

    private func recapTile(_ label: String, value: String, symbol: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 18))
                .foregroundStyle(color)
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.textPrimary)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func rpeColor(_ rpe: Double) -> Color {
        switch rpe {
        case ..<5: return Theme.accent
        case ..<7.5: return Theme.gold
        default: return Theme.danger
        }
    }
}
