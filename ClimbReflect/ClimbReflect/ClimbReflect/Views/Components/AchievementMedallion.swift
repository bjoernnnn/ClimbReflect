import SwiftUI

/// Signatur-Element "Gipfelmarke" (ERFOLGE-KONZEPT-V2 · 6.1): dunkle Plakette
/// mit eingraviertem diagonalem Grat (zitiert den `MountainBackground`),
/// außen ein Materialring (unlocked) bzw. Fortschrittsring (locked). Fixe
/// Frames — kein Layout-Sprung zwischen den Zuständen.
struct AchievementMedallion: View {
    enum State: Equatable {
        case locked(progress: Double?)
        case unlocked(material: AchievementMaterial)
    }

    let symbol: String
    let state: State
    var size: CGFloat = 56

    var body: some View {
        ZStack {
            glow
            Circle().fill(Theme.bgElevated)
            ridge
            ring.padding(size * 0.03)
            Image(systemName: symbol)
                .font(.system(size: size * 0.36, weight: .semibold))
                .foregroundStyle(iconColor)
        }
        .frame(width: size, height: size)
    }

    // MARK: - Grat (diagonale Polyline, ~8 % Weiß)

    private var ridge: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            Path { p in
                p.move(to: CGPoint(x: -0.10 * w, y: 0.86 * h))
                p.addLine(to: CGPoint(x: 0.30 * w, y: 0.50 * h))
                p.addLine(to: CGPoint(x: 0.48 * w, y: 0.66 * h))
                p.addLine(to: CGPoint(x: 0.74 * w, y: 0.34 * h))
                p.addLine(to: CGPoint(x: 1.10 * w, y: 0.62 * h))
            }
            .stroke(Color.white.opacity(0.08), lineWidth: max(1, size * 0.025))
        }
        .clipShape(Circle())
    }

    // MARK: - Ring

    @ViewBuilder private var ring: some View {
        switch state {
        case .unlocked(let material):
            Circle().strokeBorder(Theme.materialRing(material), lineWidth: 2.5)
        case .locked(let progress):
            ZStack {
                Circle().stroke(Theme.surfaceStroke, lineWidth: 3)
                if let progress {
                    Circle()
                        .trim(from: 0, to: max(0, min(1, progress)))
                        .stroke(Theme.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
            }
        }
    }

    private var iconColor: Color {
        switch state {
        case .unlocked(let material): Theme.materialColor(material)
        case .locked: Theme.textTertiary
        }
    }

    // MARK: - Material-Glow (nur unlocked, ≥ 72 pt — Detail/Overlay)

    @ViewBuilder private var glow: some View {
        if size >= 72, case .unlocked(let material) = state {
            Circle()
                .fill(RadialGradient(colors: [Theme.materialColor(material).opacity(0.28), .clear],
                                     center: .center, startRadius: 0, endRadius: size * 0.75))
                .frame(width: size * 1.7, height: size * 1.7)
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 24) {
            ForEach([CGFloat(44), 56, 96], id: \.self) { size in
                HStack(spacing: 16) {
                    AchievementMedallion(symbol: "flag.fill", state: .unlocked(material: .bronze), size: size)
                    AchievementMedallion(symbol: "flame.fill", state: .unlocked(material: .silber), size: size)
                    AchievementMedallion(symbol: "star.fill", state: .unlocked(material: .gold), size: size)
                    AchievementMedallion(symbol: "arrow.up.to.line", state: .unlocked(material: .diamant), size: size)
                }
            }
            Divider()
            ForEach([CGFloat(44), 56, 96], id: \.self) { size in
                HStack(spacing: 16) {
                    AchievementMedallion(symbol: "calendar", state: .locked(progress: nil), size: size)
                    AchievementMedallion(symbol: "calendar", state: .locked(progress: 0.0), size: size)
                    AchievementMedallion(symbol: "calendar", state: .locked(progress: 0.6), size: size)
                    AchievementMedallion(symbol: "calendar", state: .locked(progress: 0.95), size: size)
                }
            }
        }
        .padding(24)
    }
    .background(Theme.bg)
}
