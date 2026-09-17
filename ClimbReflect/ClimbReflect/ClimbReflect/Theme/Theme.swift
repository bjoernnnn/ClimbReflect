import SwiftUI

// MARK: - Farb-Theme (modern, dunkel)
// DZ-2: ruhige Fläche statt Dekoration, konsistente Text-Stufen, ein Radius-
// und ein Typo-System statt hartkodierter Werte pro View (Review Kap. 3).

enum Theme {
    // Flächen
    static let bg            = Color(hex: 0x0A0C10)   // fast schwarz
    static let surface       = Color(hex: 0x15181E)   // Karten
    static let surfaceRaised = Color(hex: 0x1D2128)   // Elemente in Karten, Chips, Buttons
    static let separator     = Color.white.opacity(0.08)

    // Text – deutlich getrennte Stufen
    static let textPrimary   = Color(hex: 0xF4F6F8)
    static let textSecondary = Color(hex: 0x9BA3AE)
    static let textTertiary  = Color(hex: 0x848D9A)   // E20: ≥ 4,8:1 auf allen Flächen

    // Bedeutung
    static let accent  = Color(hex: 0x37E29A)   // interaktiv, „du"
    static let accent2 = Color(hex: 0x29B6F6)   // nur zweite Chart-Serie
    static let gold    = Color(hex: 0xF5C451)   // ausschließlich Erreichtes
    static let danger  = Color(hex: 0xFF6B6B)   // ausschließlich destruktiv

    static var goldGradient: LinearGradient {
        LinearGradient(colors: [Color(hex: 0xFFD976), gold],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    enum Radius {
        static let small: CGFloat = 10
        static let medium: CGFloat = 14
        static let card: CGFloat = 20
    }

    enum Typo {
        static let metricHero = Font.system(.largeTitle, design: .rounded).weight(.bold)
        static let metric     = Font.system(.title2, design: .rounded).weight(.semibold)
        static let section    = Font.title3.weight(.semibold)
        static let cardTitle  = Font.headline
        static let label      = Font.footnote.weight(.medium)
    }
}

extension Shape where Self == RoundedRectangle {
    static func theme(_ radius: CGFloat) -> RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }
}

// MARK: - Wiederverwendbare Flächen-Stile

struct CardModifier: ViewModifier {
    var padding: CGFloat = 16
    func body(content: Content) -> some View {
        let shape: RoundedRectangle = .theme(Theme.Radius.card)
        return content
            .padding(padding)
            .background(shape.fill(Theme.surface))
    }
}

struct InsetModifier: ViewModifier {
    func body(content: Content) -> some View {
        let shape: RoundedRectangle = .theme(Theme.Radius.medium)
        return content
            .padding(14)
            .background(shape.fill(Theme.surfaceRaised))
    }
}

extension View {
    func card(padding: CGFloat = 16) -> some View {
        modifier(CardModifier(padding: padding))
    }

    /// DZ-2: zweite (und einzige weitere) Flächen-Ebene – Elemente innerhalb einer Karte.
    func inset() -> some View {
        modifier(InsetModifier())
    }
}

// MARK: - Color(hex:)

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(.sRGB,
                  red:   Double((hex >> 16) & 0xff) / 255,
                  green: Double((hex >> 8)  & 0xff) / 255,
                  blue:  Double( hex        & 0xff) / 255,
                  opacity: alpha)
    }
}
