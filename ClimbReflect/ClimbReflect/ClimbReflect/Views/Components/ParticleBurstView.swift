import SwiftUI

/// 24 Material-Partikel für den Unlock-Moment (ERFOLGE-KONZEPT-V2 · 7+8).
/// Bahnen (Winkel/Tempo/Lebensdauer) werden beim Erscheinen einmalig
/// vorberechnet; gezeichnet in einem `Canvas` innerhalb `TimelineView(.animation)`;
/// nach 1,4 s wird die TimelineView entfernt (kein Dauer-Ticker, S3/S19).
/// Animiert ausschließlich Position/Skalierung/Opacity — kein Layout.
struct ParticleBurstView: View {
    let material: AchievementMaterial

    private struct Particle {
        let angle: Double
        let distance: Double
        let lifetime: Double
        let colorIndex: Int
    }

    @State private var particles: [Particle] = []
    @State private var startTime: Date?
    @State private var active = false

    private var colors: [Color] {
        switch material {
        case .bronze:  [Theme.bronzeHi, Theme.bronze, Theme.bronzeDeep]
        case .silber:  [Theme.silverHi, Theme.silver, Theme.silverDeep]
        case .gold:    [Color(hex: 0xFFD976), Theme.gold, Theme.goldDeep]
        case .diamant: [Theme.diamondHi, Theme.diamond, Theme.diamondDeep]
        }
    }

    var body: some View {
        Group {
            if active {
                TimelineView(.animation) { context in
                    Canvas { ctx, size in
                        guard let startTime else { return }
                        let elapsed = context.date.timeIntervalSince(startTime)
                        let center = CGPoint(x: size.width / 2, y: size.height / 2)
                        for (i, p) in particles.enumerated() {
                            let progress = min(1, max(0, elapsed / p.lifetime))
                            guard progress < 1 else { continue }
                            let eased = 1 - pow(1 - progress, 2)
                            let dist = p.distance * eased
                            let x = center.x + cos(p.angle) * dist
                            let y = center.y + sin(p.angle) * dist
                            let scale = progress < 0.18 ? progress / 0.18 : max(0.3, 1 - (progress - 0.18) / 0.82 * 0.7)
                            let opacity = progress < 0.18 ? progress / 0.18 : max(0, 1 - (progress - 0.18) / 0.82)
                            let r = 2.6 * scale
                            ctx.opacity = opacity
                            ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                                    with: .color(colors[i % colors.count]))
                        }
                    }
                }
            }
        }
        .task {
            start()
        }
    }

    private func start() {
        particles = (0..<24).map { i in
            let base = (Double(i) / 24) * Double.pi * 2
            return Particle(angle: base + Double.random(in: -0.18...0.18),
                           distance: Double.random(in: 90...160),
                           lifetime: Double.random(in: 0.9...1.2),
                           colorIndex: i % 3)
        }
        startTime = Date()
        active = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            active = false
        }
    }
}
