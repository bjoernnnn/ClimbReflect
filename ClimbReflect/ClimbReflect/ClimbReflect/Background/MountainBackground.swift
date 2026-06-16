import SwiftUI

// Kletterwand-Hintergrund: Subtile Griff-Silhouetten und Wandplatten-Linien
// Ablösung der generischen Bergsilhouette (TODO: Hintergrund-Grafik)
// Bewusst zurückhaltend (≤ 20 % Gesamtopazität) damit UI-Text stets lesbar bleibt.

// MARK: - Wandplatten-Linien

private struct WallPanelShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        // Vertikale Fugen (Boulderwand-Panels)
        let cols = 5
        for i in 1..<cols {
            let x = rect.width * CGFloat(i) / CGFloat(cols)
            p.move(to: CGPoint(x: x, y: 0))
            p.addLine(to: CGPoint(x: x, y: rect.height))
        }
        // Horizontale Fugen
        let rows = 8
        for j in 1..<rows {
            let y = rect.height * CGFloat(j) / CGFloat(rows)
            p.move(to: CGPoint(x: 0, y: y))
            p.addLine(to: CGPoint(x: rect.width, y: y))
        }
        return p
    }
}

// MARK: - Einzelner Griff (einfache Bohnen-Form)

private struct HoldShape: Shape {
    let cx: CGFloat   // normalisiert 0…1
    let cy: CGFloat
    let angle: Double

    func path(in rect: CGRect) -> Path {
        let x = cx * rect.width
        let y = cy * rect.height
        let w: CGFloat = 18
        let h: CGFloat = 10
        var p = Path()
        p.addEllipse(in: CGRect(x: x - w / 2, y: y - h / 2, width: w, height: h))
        return p.applying(.init(rotationAngle: angle).concatenating(.init(translationX: x * (1 - cos(angle)) + y * sin(angle), y: -x * sin(angle) + y * (1 - cos(angle)))))
    }
}

// Einfacherer Ansatz: Hält-Ellipsen direkt platziert
private struct HoldEllipse: View {
    let x: CGFloat
    let y: CGFloat
    let rotation: Double

    var body: some View {
        Ellipse()
            .frame(width: 18, height: 9)
            .rotationEffect(.degrees(rotation))
            .position(x: x, y: y)
    }
}

// MARK: - Hintergrund

struct MountainBackground: View {
    // Griff-Positionen (normalisiert 0…1) und Rotation
    private let holds: [(x: CGFloat, y: CGFloat, rot: Double)] = [
        (0.10, 0.15, -20), (0.28, 0.08, 15),  (0.52, 0.12, -10), (0.75, 0.18, 25),
        (0.90, 0.07, -30), (0.18, 0.32, 40),  (0.42, 0.28, -15), (0.65, 0.35, 20),
        (0.83, 0.30, -25), (0.05, 0.50, 10),  (0.35, 0.47, -35), (0.58, 0.52, 30),
        (0.78, 0.48, -12), (0.95, 0.44, 18),  (0.15, 0.68, -22), (0.40, 0.65, 14),
        (0.62, 0.70, -18), (0.88, 0.63, 32),  (0.25, 0.82, -8),  (0.50, 0.78, 22),
        (0.72, 0.85, -28), (0.92, 0.80, 10)
    ]

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            GeometryReader { geo in
                ZStack {
                    // Subtile Wandfugen
                    WallPanelShape()
                        .stroke(Theme.accent.opacity(0.12), lineWidth: 0.5)

                    // Griff-Silhouetten
                    ForEach(holds.indices, id: \.self) { i in
                        let h = holds[i]
                        HoldEllipse(
                            x: h.x * geo.size.width,
                            y: h.y * geo.size.height,
                            rotation: h.rot
                        )
                        .foregroundStyle(Theme.accent.opacity(0.18))
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .opacity(0.20)
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear,              location: 0.00),
                        .init(color: .black.opacity(0.4), location: 0.25),
                        .init(color: .black,              location: 1.00)
                    ],
                    startPoint: .top, endPoint: .bottom)
            )
            .ignoresSafeArea()

            // Dunkle Vignette unten
            LinearGradient(colors: [.clear, Theme.bg.opacity(0.70)],
                           startPoint: .center, endPoint: .bottom)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }
}

#Preview {
    MountainBackground()
        .preferredColorScheme(.dark)
}
