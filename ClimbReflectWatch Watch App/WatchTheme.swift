import SwiftUI

enum WatchTheme {
    static let bg          = Color(hex: 0x0D1117)
    static let surface     = Color(hex: 0x161B22)
    static let elevated    = Color(hex: 0x1F2937)
    static let accent      = Color(hex: 0x30D158)
    static let accent2     = Color(hex: 0x29B6F6)   // cyan, analog iOS Theme.accent2
    static let gold        = Color(hex: 0xFFD60A)
    static let danger      = Color(hex: 0xFF453A)
    static let textPrimary = Color(hex: 0xF0F6FC)
    static let textSecond  = Color(hex: 0x8B949E)
    static let textTert    = Color(hex: 0x7A8799)
}

extension Color {
    init(hex: UInt) {
        self.init(
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >>  8) & 0xFF) / 255,
            blue:  Double( hex        & 0xFF) / 255
        )
    }
}
