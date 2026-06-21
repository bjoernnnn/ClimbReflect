import SwiftUI

// Versuch klassifizieren — Grad wählen + Ergebnis antippen = sofort banken
// Grad-Skala kommt aus App-Einstellungen (kein Wechsel während der Session)

struct AttemptLogView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    let onBank: () -> Void

    @AppStorage("watchGradeSystem") private var storedSystem: String = ""
    @State private var gradeIndex: Int = 0

    private var gradeSystem: WatchGradeSystem {
        WatchGradeSystem(rawValue: storedSystem) ?? workoutManager.sessionType.defaultGradeSystem
    }

    private struct Outcome: Identifiable {
        let id = UUID()
        let label: String
        let symbol: String
        let color: Color
        let result: WatchAscentResult
        let style: WatchAscentStyle?
    }

    private let outcomes: [Outcome] = [
        Outcome(label: "Flash",    symbol: "bolt.fill",              color: WatchTheme.gold,   result: .top,     style: .flash),
        Outcome(label: "Onsight",  symbol: "eye.fill",               color: .cyan,             result: .top,     style: .onsight),
        Outcome(label: "Rotpunkt", symbol: "checkmark.circle.fill",  color: WatchTheme.accent, result: .top,     style: .redpoint),
        Outcome(label: "Top",      symbol: "checkmark.circle",       color: WatchTheme.accent, result: .top,     style: nil),
        Outcome(label: "Versuch",  symbol: "arrow.clockwise.circle", color: WatchTheme.gold,   result: .attempt, style: nil),
        Outcome(label: "Abbruch",  symbol: "xmark.circle.fill",      color: WatchTheme.danger, result: .quit,    style: nil),
    ]

    private let columns = [GridItem(.flexible(), spacing: 5), GridItem(.flexible(), spacing: 5)]

    var body: some View {
        VStack(spacing: 6) {
            // Grad-Wheel
            Picker("Grad", selection: $gradeIndex) {
                ForEach(0..<gradeSystem.grades.count, id: \.self) { i in
                    Text(gradeSystem.grades[i]).tag(i)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 60)

            // Outcome-Grid
            LazyVGrid(columns: columns, spacing: 5) {
                ForEach(outcomes) { outcome in
                    Button {
                        let grade = gradeSystem.grades[gradeIndex]
                        Task {
                            await workoutManager.bankAttempt(
                                gradeSystem: gradeSystem,
                                grade: grade,
                                result: outcome.result,
                                style: outcome.style
                            )
                            onBank()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: outcome.symbol)
                                .font(.system(size: 12))
                                .foregroundStyle(outcome.color)
                                .frame(width: 14)
                            Text(outcome.label)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(WatchTheme.textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .truncationMode(.tail)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 9)
                        .padding(.horizontal, 8)
                        .background(WatchTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                    }
                    .buttonStyle(.plain)
                }
            }

        }
        .padding(.horizontal, 7)
        .padding(.top, 4)
        .background(WatchTheme.bg)
        .onAppear {
            gradeIndex = gradeSystem.grades.count / 2
            DiagnosticLog.shared.logVerbose("AttemptLogView appear mem=\(MemoryFootprint.residentMB())MB")
        }
        .onDisappear {
            DiagnosticLog.shared.logVerbose("AttemptLogView disappear mem=\(MemoryFootprint.residentMB())MB")
        }
    }
}
