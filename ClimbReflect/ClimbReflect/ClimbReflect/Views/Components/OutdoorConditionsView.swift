import SwiftUI
import Charts

struct OutdoorConditionsView: View {
    let sessions: [ClimbSession]
    @State private var period: ChartPeriod = .all

    private var data: [StatsEngine.ConditionRate] {
        StatsEngine.outdoorConditionRates(period.filter(sessions))
    }

    private func conditionColor(_ c: OutdoorConditions) -> Color {
        switch c {
        case .poor: return Theme.danger.opacity(0.75)
        case .ok:   return Theme.gold.opacity(0.75)
        case .good: return Theme.accent.opacity(0.75)
        }
    }

    private func conditionCard(_ rate: StatsEngine.ConditionRate) -> some View {
        VStack(spacing: 8) {
            Image(systemName: rate.conditions.symbol).font(.system(size: 22))
                .foregroundStyle(conditionColor(rate.conditions))
            Text("\(Int(rate.sendRate * 100))%")
                .font(.title3.weight(.bold)).foregroundStyle(Theme.textPrimary)
            Text(rate.conditions.rawValue)
                .font(.caption2).foregroundStyle(Theme.textTertiary)
            Text("\(rate.sessionCount) Sess.")
                .font(.caption2).foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.bgElevated))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Outdoor-Bedingungen")
                        .font(.headline).foregroundStyle(Theme.textPrimary)
                    Text("Send-Rate nach Wetterlage")
                        .font(.caption).foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                ChartPeriodPicker(selection: $period)
            }

            if data.isEmpty {
                Text("Erfasse Outdoor-Sessions mit Bedingungen um diesen Chart zu sehen.")
                    .font(.subheadline).foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                HStack(spacing: 12) {
                    ForEach(Array(data.enumerated()), id: \.offset) { _, rate in
                        conditionCard(rate)
                    }
                }
            }
        }
        .card()
    }
}

#Preview {
    OutdoorConditionsView(sessions: MockData.makeSessions())
        .padding()
        .background(Theme.bg)
}
