import SwiftUI

struct StatTile: View {
    let value: String
    let label: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.accent)
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(Theme.textPrimary)
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(2, reservesSpace: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .card(padding: 14)
    }
}

#Preview {
    HStack {
        StatTile(value: "14", label: "Sessions", symbol: "figure.climbing")
        StatTile(value: "3", label: "Wochenstreak", symbol: "flame.fill")
    }
    .padding()
    .background(Theme.bg)
}
