import SwiftUI

struct GradePyramidView: View {
    let sessions: [ClimbSession]

    @AppStorage("boulderScale") private var boulderScale: String = GradeSystem.fontainebleau.rawValue
    @AppStorage("routeScale") private var routeScale: String = GradeSystem.french.rawValue
    @State private var period: ChartPeriod = .fourWeeks
    @State private var showInfo = false

    private var selectedSystem: GradeSystem {
        GradeSystem(rawValue: boulderScale) ?? .fontainebleau
    }

    private var entries: [StatsEngine.PyramidEntry] {
        StatsEngine.gradePyramid(period.filter(sessions), system: selectedSystem)
    }

    private var maxTops: Int { entries.map(\.tops).max() ?? 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Grad-Pyramide")
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    Text("Tops nach Zeitraum und Schwierigkeit")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    ChartPeriodPicker(selection: $period)
                    Button {
                        showInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .alert("Grad-Pyramide", isPresented: $showInfo) {
                Button("OK") {}
            } message: {
                Text("Zeigt, wie viele Routen oder Boulder du je Grad gesendet hast (×N) und wie viele Versuche offen blieben (+N). Eine breite Basis bedeutet solides Volumen, eine schmale Spitze zeigt dein aktuelles Limit. Die Skala wird in den Einstellungen gewählt.")
            }

            if entries.isEmpty {
                Text("Erfasse Begehungen in deinen Sessions, um die Pyramide zu sehen.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            } else {
                VStack(spacing: 6) {
                    ForEach(entries) { entry in
                        HStack(spacing: 8) {
                            Text(GradeConverter.display(grade: entry.grade, storedIn: entry.gradeSystem))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Theme.textPrimary)
                                .frame(width: 36, alignment: .leading)

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Theme.bgElevated)
                                    if entry.tops > 0 {
                                        Capsule()
                                            .fill(Theme.accentGradient)
                                            .frame(width: max(4, geo.size.width * CGFloat(entry.tops) / CGFloat(maxTops)))
                                    }
                                }
                            }
                            .frame(height: 10)

                            HStack(spacing: 4) {
                                if entry.tops > 0 {
                                    Text("×\(entry.tops)")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Theme.accent)
                                }
                                if entry.attempts > 0 {
                                    Text("+\(entry.attempts)")
                                        .font(.caption)
                                        .foregroundStyle(Theme.gold)
                                }
                            }
                            .frame(width: 52, alignment: .trailing)
                        }
                    }
                }
            }
        }
        .card()
    }
}

#Preview {
    GradePyramidView(sessions: MockData.makeSessions())
        .padding()
        .background(Theme.bg)
}
