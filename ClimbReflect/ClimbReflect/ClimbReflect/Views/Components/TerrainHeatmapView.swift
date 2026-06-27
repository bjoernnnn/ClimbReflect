import SwiftUI

struct TerrainHeatmapView: View {
    let sessions: [ClimbSession]

    private var cells: [StatsEngine.TerrainCell] {
        StatsEngine.terrainSendRates(sessions)
    }

    private var angles: [WallAngle] { WallAngle.allCases.filter { angle in cells.contains { $0.wallAngle == angle } } }
    private var holds: [HoldType]   { HoldType.allCases.filter { hold in cells.contains { $0.holdType == hold } } }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Terrain-Heatmap")
                    .font(.headline).foregroundStyle(Theme.textPrimary)
                Text("Send-Rate nach Wandwinkel × Grifftyp")
                    .font(.caption).foregroundStyle(Theme.textSecondary)
            }

            if cells.isEmpty {
                Text("Erfasse Begehungen mit Wandwinkel und Grifftyp um die Heatmap zu sehen.")
                    .font(.subheadline).foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                grid
                legend
            }
        }
        .card()
    }

    private var grid: some View {
        VStack(spacing: 0) {
            // Header row
            HStack(spacing: 2) {
                Text("")
                    .frame(width: 66)
                ForEach(holds) { hold in
                    Text(hold.label)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.textTertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 4)

            // Data rows
            ForEach(angles) { angle in
                HStack(spacing: 2) {
                    Text(angle.label)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.textTertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(width: 66, alignment: .leading)
                    ForEach(holds) { hold in
                        cell(for: angle, hold: hold)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    @ViewBuilder
    private func cell(for angle: WallAngle, hold: HoldType) -> some View {
        if let c = cells.first(where: { $0.wallAngle == angle && $0.holdType == hold }) {
            VStack(spacing: 1) {
                Text("\(Int(c.sendRate * 100))%")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(c.sendRate >= 0.5 ? Theme.bg : Theme.textPrimary)
                Text("\(c.count)")
                    .font(.system(size: 8))
                    .foregroundStyle(c.sendRate >= 0.5 ? Theme.bg.opacity(0.7) : Theme.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 6).fill(heatColor(c.sendRate)))
        } else {
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.surfaceStroke.opacity(0.3), lineWidth: 1))
        }
    }

    private func heatColor(_ rate: Double) -> Color {
        if rate < 0.25 { return Theme.danger.opacity(0.55) }
        if rate < 0.50 { return Theme.gold.opacity(0.55) }
        if rate < 0.75 { return Theme.accent.opacity(0.55) }
        return Theme.accent.opacity(0.9)
    }

    private var legend: some View {
        HStack(spacing: 12) {
            Text("Send-Rate:")
                .font(.caption2).foregroundStyle(Theme.textTertiary)
            legendBadge(color: Theme.danger.opacity(0.55), label: "< 25%")
            legendBadge(color: Theme.gold.opacity(0.55), label: "25–50%")
            legendBadge(color: Theme.accent.opacity(0.55), label: "50–75%")
            legendBadge(color: Theme.accent.opacity(0.9), label: "> 75%")
        }
    }

    private func legendBadge(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 12, height: 12)
            Text(label).font(.caption2).foregroundStyle(Theme.textTertiary)
        }
    }
}

#Preview {
    TerrainHeatmapView(sessions: MockData.makeSessions())
        .padding()
        .background(Theme.bg)
}
