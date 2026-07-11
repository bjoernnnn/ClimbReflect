import SwiftUI

/// Kachel im Erfolge-Grid (ERFOLGE-KONZEPT-V2 · 6.4). Bestehender `card()`-Stil,
/// zentriertes 56-pt-Medaillon. Gesperrte Karten bleiben klar — kein
/// Grau-Schleier über der ganzen Karte, nur das Medaillon ist monochrom.
struct AchievementTile: View {
    let data: AchievementViewData

    private var isSecret: Bool { data.definition.isHidden && !data.isUnlocked }

    private var medallionState: AchievementMedallion.State {
        if isSecret { return .locked(progress: nil) }
        if let material = data.material { return .unlocked(material: material) }
        return .locked(progress: data.progress?.fraction)
    }

    private var displaySymbol: String { isSecret ? "questionmark" : data.definition.symbol }
    private var displayTitle: String { isSecret ? "???" : data.definition.title }

    private var statusText: String {
        if isSecret { return "Geheimer Erfolg" }
        switch data.definition.kind {
        case .once:
            if data.isUnlocked, let date = data.unlockedDate {
                return date.formatted(.dateTime.day().month(.abbreviated).year())
            }
            return data.progress?.remainingText ?? ""
        case .repeatable:
            if data.isUnlocked, let date = data.unlockedDate {
                return date.formatted(.dateTime.month(.abbreviated).year())
            }
            return data.progress?.remainingText ?? ""
        case .tiered:
            if let idx = data.currentTierIndex {
                return "Stufe \(romanNumeral(idx + 1))"
            }
            return data.progress?.remainingText ?? ""
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            AchievementMedallion(symbol: displaySymbol, state: medallionState, size: 56)
                .padding(.top, 2)
            Text(displayTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(height: 34, alignment: .top)
            Text(statusText)
                .font(.caption)
                .foregroundStyle(data.isUnlocked ? Theme.textSecondary : Theme.textTertiary)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .frame(minHeight: 14)
            footer
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 10)
        .card(padding: 0)
    }

    @ViewBuilder private var footer: some View {
        switch data.definition.kind {
        case .tiered(let tiers):
            HStack(spacing: 5) {
                ForEach(tiers.indices, id: \.self) { i in
                    let reached = i <= (data.currentTierIndex ?? -1)
                    let color = reached ? Theme.materialColor(tiers[i].material) : Theme.surfaceStroke
                    Circle().fill(reached ? color : Color.clear)
                        .overlay(Circle().stroke(color, lineWidth: 1))
                        .frame(width: 6, height: 6)
                }
            }
            .frame(height: 6)
        case .repeatable:
            if data.count > 0 {
                Text("×\(data.count) verdient")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Theme.gold)
            } else {
                Color.clear.frame(height: 6)
            }
        case .once:
            Color.clear.frame(height: 6)
        }
    }

    private func romanNumeral(_ n: Int) -> String {
        let table: [(Int, String)] = [(10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I")]
        var remaining = n, result = ""
        for (value, symbol) in table {
            while remaining >= value { result += symbol; remaining -= value }
        }
        return result
    }
}
