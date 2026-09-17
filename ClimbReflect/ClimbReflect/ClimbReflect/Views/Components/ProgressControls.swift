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

/// DZ-5: nativer Segmented-Control statt Pill-Eigenbau – volle 44-pt-Trefferfläche,
/// System-Haptik und Gleit-Animation inklusive.
struct ProgressPeriodPicker: View {
    @Binding var selection: ProgressPeriod

    var body: some View {
        Picker("Zeitraum", selection: $selection) {
            ForEach(ProgressPeriod.allCases) { period in
                Text(period.rawValue).tag(period)
            }
        }
        .pickerStyle(.segmented)
    }
}

/// Boulder|Seil-Umschalter, der direkt eine `ProgressEngine.Discipline` bindet.
struct ProgressDisciplinePicker: View {
    @Binding var discipline: ProgressEngine.Discipline

    var body: some View {
        Picker("Disziplin", selection: $discipline) {
            ForEach(ProgressEngine.Discipline.allCases) { d in
                Text(d.label).tag(d)
            }
        }
        .pickerStyle(.segmented)
    }
}
