import SwiftUI

/// „Was ist neu?"-Zeile über dem Level-Block (MO-7). Beantwortet beim Öffnen
/// zuerst die Neuigkeit, bevor der Zustandsbericht beginnt – und existiert nur,
/// wenn es echte Neuigkeit gibt (nie ein leerer Rahmen, S33). Chips scrollen
/// nicht; Überhang der Erst-Sends fasst ein „+N"-Chip zusammen.
struct PeriodHighlightsRow: View {
    let highlights: ProgressEngine.Highlights

    private var isVisible: Bool {
        !highlights.firstSends.isEmpty
            || (highlights.isAllTimeBest && highlights.hardestSend != nil)
    }

    private static let maxFirstSendChips = 3

    var body: some View {
        if isVisible {
            HStack(spacing: 8) {
                // PB-Chip: nur wenn der Zeitraum den historischen Bestwert hält.
                if highlights.isAllTimeBest, let pb = highlights.hardestSend {
                    chip(symbol: "trophy.fill", text: "Bestleistung \(pb.grade)",
                         fg: Theme.gold, bg: Theme.gold.opacity(0.12))
                }
                let shown = highlights.firstSends.prefix(Self.maxFirstSendChips)
                ForEach(shown) { first in
                    chip(symbol: "sparkles", text: "\(first.grade) erstmals",
                         fg: Theme.accent, bg: Theme.accent.opacity(0.12))
                }
                let overflow = highlights.firstSends.count - shown.count
                if overflow > 0 {
                    chip(symbol: nil, text: "+\(overflow)",
                         fg: Theme.textSecondary, bg: Theme.bgElevated)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func chip(symbol: String?, text: String, fg: Color, bg: Color) -> some View {
        HStack(spacing: 4) {
            if let symbol { Image(systemName: symbol) }
            Text(text)
        }
        .font(.caption2.weight(.semibold))
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Capsule().fill(bg))
        .foregroundStyle(fg)
    }
}
