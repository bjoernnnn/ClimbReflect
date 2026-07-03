import SwiftUI

/// Kompakter Boulder/Seil-Umschalter im Pill-Stil (analog ChartPeriodPicker).
/// Boulder- und Seilgrade liegen auf getrennten Leitern und dürfen in keiner
/// Auswertung gemischt werden – Charts zeigen daher immer EINE Disziplin.
struct DisciplinePicker: View {
    @Binding var showRoutes: Bool

    var body: some View {
        HStack(spacing: 2) {
            segment(label: "Boulder", active: !showRoutes) { showRoutes = false }
            segment(label: "Seil", active: showRoutes) { showRoutes = true }
        }
        .padding(2)
        .background(Capsule().fill(Theme.bgElevated))
    }

    private func segment(label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption2.weight(active ? .bold : .regular))
                .foregroundStyle(active ? Theme.bg : Theme.textTertiary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(active ? Theme.accent : Color.clear))
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: showRoutes)
    }
}
