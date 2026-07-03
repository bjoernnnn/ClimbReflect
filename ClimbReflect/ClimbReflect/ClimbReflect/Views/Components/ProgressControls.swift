import SwiftUI

/// Zeitraum für den Fortschritt-Tab. Liefert `monthsBack` direkt für die
/// ProgressEngine-Funktionen (nil = gesamte Historie).
enum ProgressPeriod: String, CaseIterable, Identifiable {
    case threeMonths = "3M"
    case sixMonths   = "6M"
    case oneYear     = "1J"
    case all         = "Alles"

    var id: String { rawValue }

    var monthsBack: Int? {
        switch self {
        case .threeMonths: return 3
        case .sixMonths:   return 6
        case .oneYear:     return 12
        case .all:         return nil
        }
    }
}

/// Pill-Segment-Auswahl für den Zeitraum (analog ChartPeriodPicker, aber mit den
/// Fortschritt-Perioden 3M · 6M · 1J · Alles).
struct ProgressPeriodPicker: View {
    @Binding var selection: ProgressPeriod

    var body: some View {
        HStack(spacing: 2) {
            ForEach(ProgressPeriod.allCases) { period in
                let active = selection == period
                Button { selection = period } label: {
                    Text(period.rawValue)
                        .font(.caption2.weight(active ? .bold : .regular))
                        .foregroundStyle(active ? Theme.bg : Theme.textTertiary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(active ? Theme.accent : Color.clear))
                }
                .buttonStyle(.plain)
                .animation(.easeInOut(duration: 0.15), value: selection)
            }
        }
        .padding(2)
        .background(Capsule().fill(Theme.bgElevated))
    }
}

/// Boulder|Seil-Umschalter, der direkt eine `ProgressEngine.Discipline` bindet.
struct ProgressDisciplinePicker: View {
    @Binding var discipline: ProgressEngine.Discipline

    var body: some View {
        HStack(spacing: 2) {
            segment("Boulder", active: discipline == .boulder) { discipline = .boulder }
            segment("Seil", active: discipline == .rope) { discipline = .rope }
        }
        .padding(2)
        .background(Capsule().fill(Theme.bgElevated))
    }

    private func segment(_ label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.footnote.weight(active ? .bold : .regular))
                .foregroundStyle(active ? Theme.bg : Theme.textTertiary)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Capsule().fill(active ? Theme.accent : Color.clear))
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: discipline)
    }
}
