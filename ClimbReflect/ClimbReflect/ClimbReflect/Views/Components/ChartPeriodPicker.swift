import SwiftUI

enum ChartPeriod: String, CaseIterable, Identifiable {
    case fourWeeks   = "4W"
    case threeMonths = "3M"
    case all         = "Gesamt"

    var id: String { rawValue }

    var sinceDate: Date? {
        let cal = Calendar.current
        switch self {
        case .fourWeeks:   return cal.date(byAdding: .weekOfYear, value: -4, to: .now)
        case .threeMonths: return cal.date(byAdding: .month,      value: -3, to: .now)
        case .all:         return nil
        }
    }

    func filter(_ sessions: [ClimbSession]) -> [ClimbSession] {
        guard let since = sinceDate else { return sessions }
        return sessions.filter { $0.date >= since }
    }
}

/// Kompakte Pill-Segment-Auswahl – sitzt oben rechts im Karten-Header.
struct ChartPeriodPicker: View {
    @Binding var selection: ChartPeriod

    var body: some View {
        HStack(spacing: 2) {
            ForEach(ChartPeriod.allCases) { period in
                let active = selection == period
                Button { selection = period } label: {
                    Text(period.rawValue)
                        .font(.caption2.weight(active ? .bold : .regular))
                        .foregroundStyle(active ? Theme.bg : Theme.textTertiary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(active ? Theme.accent : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .animation(.easeInOut(duration: 0.15), value: selection)
            }
        }
        .padding(2)
        .background(Capsule().fill(Theme.bgElevated))
    }
}
