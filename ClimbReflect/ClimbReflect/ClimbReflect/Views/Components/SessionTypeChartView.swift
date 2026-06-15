import SwiftUI

struct SessionTypeChartView: View {
    let sessions: [ClimbSession]

    private var distribution: [TypeCount] { StatsEngine.sessionTypeDistribution(sessions) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Sessiontypen")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)

            if distribution.isEmpty {
                Text("Noch keine Sessions.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            } else {
                VStack(spacing: 10) {
                    ForEach(distribution) { item in
                        HStack(spacing: 10) {
                            Image(systemName: item.sessionType.symbol)
                                .foregroundStyle(Theme.accent)
                                .frame(width: 18)
                            Text(item.sessionType.label)
                                .font(.subheadline)
                                .foregroundStyle(Theme.textPrimary)
                                .frame(width: 88, alignment: .leading)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Theme.bgElevated)
                                    Capsule()
                                        .fill(Theme.accentGradient)
                                        .frame(width: max(4, geo.size.width * item.share))
                                }
                            }
                            .frame(height: 8)
                            Text("\(item.count)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.textSecondary)
                                .frame(width: 24, alignment: .trailing)
                        }
                    }
                }
            }
        }
        .card()
    }
}

#Preview {
    SessionTypeChartView(sessions: MockData.makeSessions())
        .padding()
        .background(Theme.bg)
}
