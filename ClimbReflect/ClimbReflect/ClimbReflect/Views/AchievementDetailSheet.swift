import SwiftUI

/// Detail-Sheet einer Gipfelmarke (ERFOLGE-KONZEPT-V2 · 6.4 Punkt 5).
struct AchievementDetailSheet: View {
    let data: AchievementViewData

    private var isSecret: Bool { data.definition.isHidden && !data.isUnlocked }

    private var medallionState: AchievementMedallion.State {
        if isSecret { return .locked(progress: nil) }
        if let material = data.material { return .unlocked(material: material) }
        return .locked(progress: data.progress?.fraction)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                medallionWithAura
                Text(isSecret ? "Geheimer Erfolg" : data.definition.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                materialChip

                if isSecret {
                    Text("Wird beim Freischalten enthüllt.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                } else {
                    Text(data.definition.criterion)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    if let progress = data.progress {
                        progressRow(progress)
                    }

                    if !data.events.isEmpty {
                        historySection
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 8)
            .padding(.bottom, 30)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.bgElevated.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    private var medallionWithAura: some View {
        // ER-2: Der Material-Glow rendert ab size ≥ 72 mit Frame size*1.7 (≈163 pt)
        // und ragte ohne reservierten Platz in den Titel darunter. Fester Rahmen
        // schließt die Aura ein, statt sie überlaufen zu lassen.
        AchievementMedallion(symbol: isSecret ? "questionmark" : data.definition.symbol,
                             state: medallionState, size: 96)
            .frame(width: 96 * 1.7, height: 96 * 1.7)
    }

    private var materialChip: some View {
        let text: String
        let color: Color
        if isSecret {
            text = "Verborgen"
            color = Theme.textTertiary
        } else if let material = data.material {
            text = "Freigeschaltet · \(materialName(material))"
            color = Theme.materialColor(material)
        } else {
            text = "Gesperrt"
            color = Theme.textTertiary
        }
        return Text(text.uppercased())
            .font(.caption2.weight(.bold))
            .tracking(0.4)
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(color.opacity(0.12)))
    }

    private func progressRow(_ progress: AchievementEngine.AchievementProgress) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(progress.remainingText)
                Spacer()
                Text("\(Int((progress.fraction * 100).rounded())) %")
            }
            .font(.caption)
            .foregroundStyle(Theme.textTertiary)
            .monospacedDigit()

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.surface)
                    Capsule().fill(Theme.accent)
                        .frame(width: geo.size.width * CGFloat(progress.fraction))
                }
            }
            .frame(height: 5)
        }
        .padding(.top, 4)
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Historie".uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(0.4)
                .foregroundStyle(Theme.textTertiary)
            ForEach(data.events.reversed(), id: \.id) { event in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(event.contextValue ?? tierLabel(event.tier))
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.gold)
                    Text(data.definition.title)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Text(event.unlockedAt.formatted(.dateTime.day().month().year()))
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                }
                .padding(.top, 9)
                .overlay(alignment: .top) { Divider().overlay(Theme.surfaceStroke) }
            }
        }
        .padding(.top, 8)
    }

    private func tierLabel(_ tier: Int?) -> String {
        guard let tier, case .tiered(let tiers) = data.definition.kind, tiers.indices.contains(tier)
        else { return "" }
        return tiers[tier].name ?? "Stufe \(tier + 1)"
    }

    private func materialName(_ material: AchievementMaterial) -> String {
        switch material {
        case .bronze:  "Bronze"
        case .silber:  "Silber"
        case .gold:    "Gold"
        case .diamant: "Diamant"
        }
    }
}
