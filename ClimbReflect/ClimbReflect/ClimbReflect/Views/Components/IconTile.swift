import SwiftUI

/// PG-2/E22: eine Icon-Kachel-Form in der App – abgerundetes Quadrat statt
/// wechselnder Kreise/Quadrate. Kreise bleiben ProgressRing/MilestoneRow vorbehalten.
struct IconTile: View {
    let symbol: String
    var tint: Color = Theme.accent
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: symbol)
            .font(.body.weight(.semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous).fill(tint.opacity(0.14)))
            .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: 12) {
        IconTile(symbol: "figure.climbing")
        IconTile(symbol: "target", tint: Theme.gold, size: 52)
    }
    .padding()
    .background(Theme.bg)
}
