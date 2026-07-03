import SwiftUI

/// Zentrierte Grad-Pyramide: je Zeile ein Grad (härtester oben), ein zur Mitte
/// ausgerichteter Balken. Der volle Teil sind Sends, die transparente Verlängerung
/// die Begehungen ohne Send. Zahlen am Balkenende: „Sends · offene Versuche“.
struct PyramidChart: View {
    let rows: [ProgressEngine.PyramidRow]

    private var maxTotal: Int {
        rows.map { $0.sends + $0.failedTries }.max() ?? 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pyramide")
                .font(.headline).foregroundStyle(Theme.textPrimary)

            if rows.isEmpty {
                Text("Noch keine bewerteten Begehungen im Zeitraum.")
                    .font(.subheadline).foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                VStack(spacing: 6) {
                    ForEach(rows) { row in
                        PyramidRowView(row: row, maxTotal: maxTotal)
                    }
                }
            }
        }
        .card()
    }
}

private struct PyramidRowView: View {
    let row: ProgressEngine.PyramidRow
    let maxTotal: Int

    private var total: Int { row.sends + row.failedTries }

    var body: some View {
        HStack(spacing: 8) {
            Text(row.grade)
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 46, alignment: .trailing)

            GeometryReader { geo in
                let maxBar = geo.size.width * 0.7   // Platz für Zahlen am Ende lassen
                let barW = maxBar * CGFloat(total) / CGFloat(max(maxTotal, 1))
                let sendW = total > 0 ? barW * CGFloat(row.sends) / CGFloat(total) : 0

                HStack(spacing: 6) {
                    HStack(spacing: 0) {
                        Rectangle().fill(Theme.accent)
                            .frame(width: sendW)
                        Rectangle().fill(Theme.accent.opacity(0.25))
                            .frame(width: barW - sendW)
                    }
                    .frame(height: 16)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                    Text(row.failedTries > 0 ? "\(row.sends) · \(row.failedTries)" : "\(row.sends)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(Theme.textTertiary)
                        .fixedSize()
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .frame(height: geo.size.height)
            }
            .frame(height: 18)
        }
    }
}
