import SwiftUI

struct StartInsightCarousel: View {
    let sessions: [ClimbSession]

    private var cards: [StatsEngine.InsightCard] {
        StatsEngine.startCards(sessions)
    }

    var body: some View {
        if cards.isEmpty { EmptyView() } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("Dein Status")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.leading, 2)

                TabView {
                    ForEach(cards) { card in
                        insightCard(card)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(height: 108)
            }
        }
    }

    private func insightCard(_ card: StatsEngine.InsightCard) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(card.color.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: card.symbol)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(card.color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(card.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textTertiary)
                if !card.value.isEmpty {
                    Text(card.value)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Theme.textPrimary)
                }
                Text(card.subtitle)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(card.color.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.horizontal, 2)
        .padding(.bottom, 24) // space for dots
    }
}

#Preview {
    StartInsightCarousel(sessions: MockData.makeSessions())
        .padding()
        .background(Theme.bg)
}
