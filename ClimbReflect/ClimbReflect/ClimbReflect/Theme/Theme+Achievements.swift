import SwiftUI

// ERFOLGE-KONZEPT-V2 · 6.2: Wertigkeits-Materialien der "Gipfelmarken".
// Farbwerte 1:1 aus achievement-mockup.html übernommen (Design-Referenz).

extension Theme {
    static let bronze     = Color(hex: 0xC9905E)
    static let bronzeHi   = Color(hex: 0xE8B888)
    static let bronzeDeep = Color(hex: 0x8A5A34)

    static let silver     = Color(hex: 0xC9D4E0)
    static let silverHi   = Color(hex: 0xEEF3F8)
    static let silverDeep = Color(hex: 0x7E8C9E)

    // Gold nutzt den bestehenden Hell-Stop aus goldGradient (0xFFD976);
    // goldDeep ergänzt den dritten Stop für den Materialring.
    static let goldDeep = Color(hex: 0xB98A28)

    static let diamond     = Color(hex: 0xA8ECFF)
    static let diamondHi   = Color(hex: 0xDFF8FF)
    static let diamondDeep = Color(hex: 0x4FC3F7)

    /// Metallischer Materialring ([deep, hell, deep]) — dezent, nie neonhaft.
    static func materialRing(_ material: AchievementMaterial) -> AngularGradient {
        let stops: [Color]
        switch material {
        case .bronze:  stops = [bronzeDeep, bronzeHi, bronzeDeep]
        case .silber:  stops = [silverDeep, silverHi, silverDeep]
        case .gold:    stops = [goldDeep, Color(hex: 0xFFD976), goldDeep]
        case .diamant: stops = [diamondDeep, diamondHi, diamondDeep]
        }
        return AngularGradient(colors: stops, center: .center)
    }

    /// Flächenfarbe des Materials (Symbol, Chips, Punkte-Reihen).
    static func materialColor(_ material: AchievementMaterial) -> Color {
        switch material {
        case .bronze:  bronze
        case .silber:  silver
        case .gold:    gold
        case .diamant: diamond
        }
    }
}
