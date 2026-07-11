import SwiftUI

/// Leise Feier für `.quiet`-Erfolge (ERFOLGE-KONZEPT-V2 · L7): kompakte Kapsel
/// oben statt Vollbild-Overlay — wiederholbare Session-Erfolge (flash_day,
/// big_day) sollen den einen Feier-Kanal nicht entwerten.
struct AchievementToast: View {
    let unlock: AchievementUnlock

    @AppStorage("achievementEffectsEnabled") private var effectsEnabled = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appear = false

    private var definition: AchievementDefinition? { AchievementDefinition.definition(id: unlock.definitionID) }

    private var material: AchievementMaterial {
        guard let def = definition else { return .silber }
        switch def.kind {
        case .once(let m), .repeatable(let m): return m
        case .tiered(let tiers):
            if let t = unlock.tier, tiers.indices.contains(t) { return tiers[t].material }
            return .silber
        }
    }

    private var reduced: Bool { !effectsEnabled || reduceMotion }

    var body: some View {
        HStack(spacing: 10) {
            AchievementMedallion(symbol: definition?.symbol ?? "bolt.fill",
                                 state: .unlocked(material: material), size: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text("Erfolg freigeschaltet".uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(Theme.textTertiary)
                Text(definition?.title ?? "")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Capsule().fill(Theme.bgElevated))
        .overlay(Capsule().stroke(Theme.surfaceStroke, lineWidth: 1))
        .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
        .opacity(appear ? 1 : 0)
        .offset(y: appear ? 0 : -16)
        .onAppear {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            if reduced {
                appear = true
            } else {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { appear = true }
            }
        }
    }
}
