import SwiftUI
import Charts

/// Volumen-Karte (Konzept ④): bewusst kompakt. Mini-Balken der Klettertage je
/// Monat (feste 6-Monats-Historie) + eine Zeile Sends/Klettertage für den
/// gewählten Zeitraum.
struct ClimbDaysCard: View {
    let monthlyDays: [(month: Date, days: Int)]
    let sends: Int
    let climbDays: Int
    let discipline: ProgressEngine.Discipline

    private var title: String { discipline == .rope ? "Seiltage" : "Bouldertage" }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline).foregroundStyle(Theme.textPrimary)

            Chart(monthlyDays, id: \.month) { item in
                BarMark(x: .value("Monat", item.month, unit: .month),
                        y: .value("Tage", item.days))
                    .foregroundStyle(Theme.accent)
                    .cornerRadius(3)
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                    AxisValueLabel().foregroundStyle(Theme.textTertiary)
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { _ in
                    AxisValueLabel(format: .dateTime.month(.narrow))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .frame(height: 80)

            Text("\(sends) Sends · \(climbDays) Klettertage")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
        }
        .card()
    }
}
