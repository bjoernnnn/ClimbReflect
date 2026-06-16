import SwiftUI

// MARK: - Berg-/Kletterwand-Hintergrund
//
// Eine diagonale Bergsilhouette (zwei Grate für Tiefe), die nach oben hin
// ausfadet. Komplett in SwiftUI gezeichnet – kein Bild-Asset nötig, skaliert
// auf jede Bildschirmgröße. Gesamtstärke bewusst bei ~26 % (Wunsch: 20–30 %).

private struct RidgeShape: Shape {
    /// Normalisierte Grat-Punkte (x, y jeweils 0…1; y von oben gemessen).
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var p = Path()
        guard let first = points.first else { return p }
        p.move(to: CGPoint(x: first.x * rect.width, y: first.y * rect.height))
        for pt in points.dropFirst() {
            p.addLine(to: CGPoint(x: pt.x * rect.width, y: pt.y * rect.height))
        }
        // Bis zum unteren Rand schließen → gefüllte Bergmasse
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

struct MountainBackground: View {
    // Hinterer Grat (höher, dezenter) – steigt diagonal nach rechts oben an
    private let backRidge: [CGPoint] = [
        .init(x: 0.00, y: 0.72), .init(x: 0.12, y: 0.57), .init(x: 0.20, y: 0.63),
        .init(x: 0.33, y: 0.41), .init(x: 0.45, y: 0.51), .init(x: 0.57, y: 0.31),
        .init(x: 0.69, y: 0.41), .init(x: 0.81, y: 0.21), .init(x: 0.91, y: 0.29),
        .init(x: 1.00, y: 0.13)
    ]
    // Vorderer Grat (tiefer, kräftiger)
    private let frontRidge: [CGPoint] = [
        .init(x: 0.00, y: 0.90), .init(x: 0.10, y: 0.80), .init(x: 0.23, y: 0.86),
        .init(x: 0.35, y: 0.67), .init(x: 0.47, y: 0.76), .init(x: 0.59, y: 0.57),
        .init(x: 0.71, y: 0.66), .init(x: 0.83, y: 0.47), .init(x: 0.93, y: 0.55),
        .init(x: 1.00, y: 0.39)
    ]

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            // Bergmassiv
            GeometryReader { geo in
                ZStack {
                    RidgeShape(points: backRidge)
                        .fill(
                            LinearGradient(colors: [Theme.accent2, Theme.accent],
                                           startPoint: .topTrailing, endPoint: .bottomLeading)
                        )
                    RidgeShape(points: frontRidge)
                        .fill(
                            LinearGradient(colors: [Theme.accent, Theme.accent2],
                                           startPoint: .topTrailing, endPoint: .bottomLeading)
                        )
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .opacity(0.26)                              // Gesamtstärke 20–30 %
            .mask(                                      // Fade nach oben hin
                LinearGradient(
                    stops: [
                        .init(color: .clear,                 location: 0.00),
                        .init(color: .black.opacity(0.45),   location: 0.32),
                        .init(color: .black,                 location: 1.00)
                    ],
                    startPoint: .top, endPoint: .bottom)
            )
            .ignoresSafeArea()

            // Dunkle Vignette unten – hält Text gut lesbar
            LinearGradient(colors: [.clear, Theme.bg.opacity(0.65)],
                           startPoint: .center, endPoint: .bottom)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }
}

#Preview {
    MountainBackground()
}
