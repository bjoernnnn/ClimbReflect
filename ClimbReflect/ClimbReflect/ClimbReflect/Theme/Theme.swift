import SwiftUI

// MARK: - Farb-Theme (modern, dunkel)

enum Theme {
    // Hintergründe
    static let bg            = Color(hex: 0x0B0E13)   // fast schwarz, leicht blaustichig
    static let bgElevated    = Color(hex: 0x12161D)
    static let surface       = Color(hex: 0x171C25)   // Karten
    static let surfaceStroke = Color(hex: 0x232B37)

    // Text
    static let textPrimary   = Color(hex: 0xF2F5F9)
    static let textSecondary = Color(hex: 0x8B97A7)
    static let textTertiary  = Color(hex: 0x5C6675)

    // Akzente
    static let accent  = Color(hex: 0x37E29A)         // Mint/Grün
    static let accent2 = Color(hex: 0x29B6F6)         // Cyan/Blau
    static let gold    = Color(hex: 0xF5C451)         // Erfolge
    static let danger  = Color(hex: 0xFF6B6B)

    static var accentGradient: LinearGradient {
        LinearGradient(colors: [accent, accent2],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var goldGradient: LinearGradient {
        LinearGradient(colors: [Color(hex: 0xFFD976), gold],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Wiederverwendbarer Karten-Stil

struct CardModifier: ViewModifier {
    var padding: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Theme.surface.opacity(0.85))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Theme.surfaceStroke, lineWidth: 1)
            )
    }
}

extension View {
    func card(padding: CGFloat = 16) -> some View {
        modifier(CardModifier(padding: padding))
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
