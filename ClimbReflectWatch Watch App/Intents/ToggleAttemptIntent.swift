import AppIntents

// AB-4: Re-chainender Intent – Hardware-Zwilling der Versuche-Badge.
// Jeder Druck ruft WorkoutManager.handleActionButton() und verkettet sich selbst.
// handleActionButton() hat guard isRunning – kein Geister-Versuch nach Jetsam-Kill.
// openAppWhenRun = true: App öffnet beim awaitingResult-Übergang → Ergebnis-Overlay sichtbar.

// AB-K: nonisolated – siehe StartSessionIntent.swift (AppIntents-Runtime
// instanziiert Intents off-main; MainActor-Default-Isolation crasht dort).
nonisolated struct ToggleAttemptIntent: AppIntent {
    static let title: LocalizedStringResource = "Versuch tracken"
    static let openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        let manager = WorkoutManager.shared
        // flushImmediately: Beweis auf Disk, auch wenn der Prozess direkt danach stirbt
        DiagnosticLog.shared.log("ToggleAttemptIntent: isRunning=\(manager.isRunning) state=\(String(describing: manager.attemptState))", flushImmediately: true)
        manager.handleActionButton()
        return .result(actionButtonIntent: ToggleAttemptIntent())
    }
}
