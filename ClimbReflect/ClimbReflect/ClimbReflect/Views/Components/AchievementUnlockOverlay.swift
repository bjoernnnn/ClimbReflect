import SwiftUI

/// Vollbild-Unlock-Moment (ERFOLGE-KONZEPT-V2 · 7+8) für `.full`-Erfolge.
/// Nur `transform`/`opacity` animiert, kein Layout-Shift. Reduzierte Variante
/// (Effekte-Toggle aus ODER `accessibilityReduceMotion`): reiner Crossfade
/// ohne Skalierung/Partikel/Glanz — die Haptik bleibt in jedem Fall.
struct AchievementUnlockOverlay: View {
    let unlock: AchievementUnlock
    /// z. B. "1 von 3"; nil bei genau einem Unlock in der Queue.
    let pagerText: String?
    let onAdvance: () -> Void

    @AppStorage("achievementEffectsEnabled") private var effectsEnabled = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var appear = false

    private var definition: AchievementDefinition? { AchievementDefinition.definition(id: unlock.definitionID) }

    private var material: AchievementMaterial {
        guard let def = definition else { return .gold }
        switch def.kind {
        case .once(let m), .repeatable(let m): return m
        case .tiered(let tiers):
            if let t = unlock.tier, tiers.indices.contains(t) { return tiers[t].material }
            return .gold
        }
    }

    private var reduced: Bool { !effectsEnabled || reduceMotion }

    private var subtitle: String {
        if let def = definition, case .tiered(let tiers) = def.kind,
           let t = unlock.tier, tiers.indices.contains(t), let name = tiers[t].name {
            return name
        }
        if let value = unlock.contextValue { return value }
        return definition?.criterion ?? ""
    }

    var body: some View {
        ZStack {
            Color.black
                .opacity(appear ? 0.55 : 0)
                .ignoresSafeArea()
                .animation(.easeOut(duration: reduced ? 0.26 : 0.2), value: appear)

            if let pagerText {
                Text(pagerText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textTertiary)
                    .opacity(appear ? 1 : 0)
                    .animation(.easeOut(duration: 0.3).delay(0.2), value: appear)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 24)
            }

            VStack(spacing: 0) {
                stage
                    .frame(height: 176)

                Text("Erfolg freigeschaltet".uppercased())
                    .font(.caption.weight(.bold))
                    .tracking(1.4)
                    .foregroundStyle(Theme.textTertiary)
                    .modifier(RiseIn(appear: appear, delay: reduced ? 0.15 : 0.35))
                    .padding(.top, 20)

                Text(definition?.title ?? "")
                    .font(.system(.title2, design: .rounded).weight(.heavy))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .modifier(RiseIn(appear: appear, delay: reduced ? 0.18 : 0.41))
                    .padding(.top, 4)
                    .padding(.horizontal, 24)

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .modifier(RiseIn(appear: appear, delay: reduced ? 0.21 : 0.47))
                        .padding(.top, 4)
                        .padding(.horizontal, 32)
                }

                Button(action: onAdvance) {
                    Text("Weiter")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.bg)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 11)
                        .background(Capsule().fill(Theme.textPrimary))
                }
                .buttonStyle(.plain)
                .opacity(appear ? 1 : 0)
                .animation(.easeOut(duration: 0.25).delay(reduced ? 0.7 : 1.5), value: appear)
                .padding(.top, 28)
            }
        }
        .onAppear { play() }
    }

    // MARK: - Bühne: Glow + Partikel + Medaillon

    @ViewBuilder private var stage: some View {
        ZStack {
            if !reduced {
                Circle()
                    .fill(RadialGradient(colors: [Theme.materialColor(material).opacity(0.9),
                                                  Theme.materialColor(material).opacity(0.3), .clear],
                                         center: .center, startRadius: 0, endRadius: 170))
                    .frame(width: 340, height: 340)
                    .opacity(appear ? 0.35 : 0)
                    .scaleEffect(appear ? 1.15 : 0.8)
                    .animation(.easeOut(duration: 0.45), value: appear)

                ParticleBurstView(material: material)
                    .frame(width: 260, height: 260)
            }

            AchievementMedallion(symbol: definition?.symbol ?? "star.fill",
                                 state: .unlocked(material: material), size: 128)
                .scaleEffect(appear ? 1 : (reduced ? 1 : 0.6))
                .opacity(appear ? 1 : 0)
                .animation(reduced ? .easeOut(duration: 0.32)
                                   : .spring(response: 0.45, dampingFraction: 0.7).delay(0.06),
                          value: appear)
        }
    }

    private func play() {
        let haptic = UINotificationFeedbackGenerator()
        haptic.prepare()
        appear = true
        haptic.notificationOccurred(.success)
    }
}

/// Gemeinsame „von unten einfliegen + einblenden"-Textanimation (opacity + offset).
private struct RiseIn: ViewModifier {
    let appear: Bool
    let delay: Double
    func body(content: Content) -> some View {
        content
            .opacity(appear ? 1 : 0)
            .offset(y: appear ? 0 : 8)
            .animation(.easeOut(duration: 0.3).delay(delay), value: appear)
    }
}
