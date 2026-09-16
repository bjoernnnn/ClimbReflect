import SwiftUI
import WatchKit

// Versuch klassifizieren — Grad wählen + Ergebnis antippen = sofort banken
// RP-4: Grad-Skala leitet sich aus dem Session-Typ ab (Seil → french, Boulder →
// fontainebleau), nicht aus einer App-Einstellung.

struct AttemptLogView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    let onBank: () -> Void

    // nil = noch kein Grad gewählt → Klassifizieren ist gesperrt, bis per Krone ein
    // Grad ausgewählt wurde (oder ein Projekt-Grad vorbelegt ist).
    @State private var gradeIndex: Int? = nil
    // Kurzes rotes Aufblinken des Grad-Rahmens als Signal „Grad fehlt".
    @State private var gradeMissingFlash = false

    // FB-2: aktives Projekt mit Grad → dessen System (sonst Session-Default, RP-4)
    private var gradeSystem: WatchGradeSystem {
        if let raw = workoutManager.selectedProject?.gradeSystem,
           let sys = WatchGradeSystem(rawValue: raw) { return sys }
        return workoutManager.sessionType.defaultGradeSystem
    }

    // FB-2: gradeIndex auf den Projekt-Grad vorbelegen (Nutzer kann per Crown abweichen)
    private func prefillFromProject() {
        guard let grade = workoutManager.selectedProject?.grade,
              let idx = gradeSystem.grades.firstIndex(of: grade) else { return }
        gradeIndex = idx
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

    private let columns = [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)]

    var body: some View {
        VStack(spacing: 6) {
            // Grad per Digital Crown
            HStack {
                Text(gradeIndex.map { gradeSystem.grades[$0] } ?? "–")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(gradeIndex == nil ? WatchTheme.textTert : WatchTheme.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    // Roter Rahmen: normal leer (nur Kontur), blinkt bei fehlendem Grad
                    // kurz gefüllt auf.
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(WatchTheme.danger.opacity(gradeMissingFlash ? 0.55 : 0))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(WatchTheme.danger, lineWidth: 1.5)
                    )
                    .focusable(true)
                    .digitalCrownRotation(
                        Binding(get: { Double(gradeIndex ?? 0) },
                                set: { gradeIndex = min(max(Int($0.rounded()), 0), gradeSystem.grades.count - 1) }),
                        from: 0, through: Double(gradeSystem.grades.count - 1), by: 1,
                        sensitivity: .low, isContinuous: false)
                Spacer(minLength: 0)
            }
            .padding(.top, -6)
            .padding(.leading, 3)

            // Outcome-Grid
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(outcomes) { outcome in
                    Button {
                        // Ohne gewählten Grad kein Tracken: rotes Signal geben, nicht banken.
                        guard let idx = gradeIndex else {
                            signalMissingGrade()
                            return
                        }
                        let grade = gradeSystem.grades[idx]
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
                                .font(.system(size: 15))
                                .foregroundStyle(outcome.color)
                                .frame(width: 18)
                            Text(outcome.label)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(WatchTheme.textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .truncationMode(.tail)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 8)
                        .background(WatchTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                    }
                    .buttonStyle(.plain)
                }
            }

        }
        .padding(.horizontal, 3)
        .padding(.top, 4)
        .background(WatchTheme.bg)
        .onAppear {
            // WT-1/E5: letzte Session-Begehung → Projekt → 0 (S37).
            if let last = workoutManager.attempts.last(where: { $0.grade != nil && $0.gradeSystem == gradeSystem }),
               let grade = last.grade,
               let idx = gradeSystem.grades.firstIndex(of: grade) {
                gradeIndex = idx
            } else if workoutManager.selectedProject?.grade != nil {
                prefillFromProject()
            } else {
                gradeIndex = 0
            }
            DiagnosticLog.shared.logVerbose("AttemptLogView appear mem=\(MemoryFootprint.residentMB())MB")
        }
        .onDisappear {
            DiagnosticLog.shared.logVerbose("AttemptLogView disappear mem=\(MemoryFootprint.residentMB())MB")
        }
    }

    /// Kein Grad gewählt: kurzes rotes Aufblinken des Rahmens + Fehler-Haptik.
    private func signalMissingGrade() {
        WKInterfaceDevice.current().play(.failure)
        withAnimation(.easeIn(duration: 0.1)) { gradeMissingFlash = true }
        Task {
            try? await Task.sleep(nanoseconds: 260_000_000)
            withAnimation(.easeOut(duration: 0.25)) { gradeMissingFlash = false }
        }
    }
}
