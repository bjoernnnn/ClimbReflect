import SwiftUI

struct FormSignalView: View {
    let signal: StatsEngine.FormSignal

    var body: some View {
        if signal != .formGood {
            HStack(spacing: 12) {
                Image(systemName: signal == .deloadSuggested ? "battery.25" : "brain.head.profile")
                    .font(.title3)
                    .foregroundStyle(Theme.gold)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Theme.gold.opacity(0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Theme.gold.opacity(0.25), lineWidth: 1)
                    )
            )
        }
    }

    private var title: String {
        switch signal {
        case .deloadSuggested:   "Deload erwägen?"
        case .techniqueSuggested: "Technikwoche?"
        case .formGood:          ""
        }
    }

    private var subtitle: String {
        switch signal {
        case .deloadSuggested:   "RPE hoch, Send-Rate sinkt — vielleicht eine leichtere Woche einplanen."
        case .techniqueSuggested: "Grad stagniert bei hohem Aufwand — bewusstes Techniküben könnte helfen."
        case .formGood:          ""
        }
    }
}
