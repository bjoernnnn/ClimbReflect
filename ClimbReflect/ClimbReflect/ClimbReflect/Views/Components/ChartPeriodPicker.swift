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

struct ChartPeriodPicker: View {
    @Binding var selection: ChartPeriod

    var body: some View {
        Picker("Zeitraum", selection: $selection) {
            ForEach(ChartPeriod.allCases) { p in
                Text(p.rawValue).tag(p)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 160)
    }
}
