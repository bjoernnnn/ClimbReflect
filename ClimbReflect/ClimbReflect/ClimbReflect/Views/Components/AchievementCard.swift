import SwiftUI

struct AchievementCard: View {
    let achievement: Achievement

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                Circle()
                    .fill(achievement.isUnlocked
                          ? AnyShapeStyle(Theme.goldGradient)
                          : AnyShapeStyle(Theme.surfaceStroke.opacity(0.6)))
                    .frame(width: 46, height: 46)
                Image(systemName: achievement.symbol)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(achievement.isUnlocked ? Color(hex: 0x1A1300) : Theme.textTertiary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(achievement.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(achievement.isUnlocked ? Theme.textPrimary : Theme.textSecondary)
                Text(achievement.subtitle)
                    .font(.caption2)
                    .foregroundStyle(Theme.textTertiary)
            }

            if !achievement.isUnlocked {
                ProgressView(value: achievement.progress)
                    .tint(Theme.accent)
                    .scaleEffect(x: 1, y: 0.7, anchor: .center)
            }
        }
        .frame(width: 132, height: 132, alignment: .topLeading)
        .card(padding: 14)
        .opacity(achievement.isUnlocked ? 1 : 0.7)
        .overlay(alignment: .topTrailing) {
            if achievement.isUnlocked {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.gold)
                    .padding(10)
            }
        }
    }
}

#Preview {
    HStack {
        AchievementCard(achievement: .init(id: "1", title: "Stammgast",
            subtitle: "Geschafft", symbol: "medal.fill", isUnlocked: true, progress: 1))
        AchievementCard(achievement: .init(id: "2", title: "Eisern",
            subtitle: "14/20 Sessions", symbol: "trophy.fill", isUnlocked: false, progress: 0.7))
    }
    .padding()
    .background(Theme.bg)
}
