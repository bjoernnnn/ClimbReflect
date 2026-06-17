import SwiftUI
import SwiftData

struct AchievementsView: View {
    @Query(sort: \ClimbSession.date, order: .reverse) private var sessions: [ClimbSession]
    @State private var selectedAchievementID: String?

    private var selectedAchievement: StatsEngine.ClimbAchievement? {
        allAchievements.first { $0.id == selectedAchievementID }
    }

    private var climbAchievements: [StatsEngine.ClimbAchievement] {
        StatsEngine.climbAchievements(for: sessions)
    }

    private var appAchievements: [Achievement] {
        StatsEngine.achievements(for: sessions)
    }

    private var allAchievements: [StatsEngine.ClimbAchievement] {
        let app = appAchievements.map { a in
            StatsEngine.ClimbAchievement(
                id: a.id,
                title: a.title,
                subtitle: a.subtitle,
                symbol: a.symbol,
                isUnlocked: a.isUnlocked,
                color: Theme.accent,
                explanation: a.id == "first"
                    ? "Du hast deine erste Session erfasst. Der erste Schritt auf dem Weg zur Verbesserung!"
                    : "Du warst mindestens 4 Wochen in Folge aktiv. Konsistenz ist der Schlüssel zum Fortschritt."
            )
        }
        return climbAchievements + app
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MountainBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        achievementsGrid
                        betaLibraryLink
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Erfolge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(isPresented: .constant(selectedAchievementID != nil),
                   onDismiss: { selectedAchievementID = nil }) {
                if let a = selectedAchievement { achievementDetail(a) }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var achievementsGrid: some View {
        let unlocked = allAchievements.filter(\.isUnlocked).count
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Erfolge")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("\(unlocked)/\(allAchievements.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(allAchievements) { a in
                        Button { selectedAchievementID = a.id } label: {
                            VStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(a.isUnlocked ? a.color.opacity(0.15) : Theme.bgElevated)
                                        .frame(width: 52, height: 52)
                                    Image(systemName: a.symbol)
                                        .font(.system(size: 22))
                                        .foregroundStyle(a.isUnlocked ? a.color : Theme.textTertiary)
                                }
                                Text(a.title)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(a.isUnlocked ? Theme.textPrimary : Theme.textTertiary)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .frame(width: 72, height: 28, alignment: .top)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 8)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(a.isUnlocked ? a.color.opacity(0.3) : Color.clear, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
            }
            .scrollClipDisabled()
        }
    }

    private var betaLibraryLink: some View {
        NavigationLink(destination: BetaLibraryView()) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Theme.accent.opacity(0.12)).frame(width: 44, height: 44)
                    Image(systemName: "text.magnifyingglass")
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.accent)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Beta-Bibliothek")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Tipps & Techniken für Kletterprobleme")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface))
        }
        .buttonStyle(.plain)
    }

    private func achievementDetail(_ a: StatsEngine.ClimbAchievement) -> some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(a.isUnlocked ? a.color.opacity(0.15) : Theme.bgElevated)
                    .frame(width: 80, height: 80)
                Image(systemName: a.symbol)
                    .font(.system(size: 36))
                    .foregroundStyle(a.isUnlocked ? a.color : Theme.textTertiary)
            }
            .padding(.top, 28)

            VStack(spacing: 8) {
                Text(a.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                Text(a.isUnlocked ? "Freigeschaltet ✓" : "Noch gesperrt")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(a.isUnlocked ? a.color : Theme.textTertiary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(a.isUnlocked ? a.color.opacity(0.12) : Theme.bgElevated))
            }

            Text(a.explanation)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Text(a.subtitle)
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Theme.bg.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}
