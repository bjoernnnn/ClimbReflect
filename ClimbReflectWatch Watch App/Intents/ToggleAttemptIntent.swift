import AppIntents

// AB-4: Re-chainender Intent – Hardware-Zwilling der Versuche-Badge.
// Jeder Druck ruft WorkoutManager.handleActionButton() und verkettet sich selbst.
// openAppWhenRun = true: App öffnet beim awaitingResult-Übergang → Ergebnis-Overlay sichtbar.

@available(watchOS 10.0, *)
struct ToggleAttemptIntent: AppIntent {
    static let title: LocalizedStringResource = "Versuch tracken"
    static let openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        let manager = WorkoutManager.shared
        if manager.isRunning {
            manager.handleActionButton()
        }
        return .result(actionButtonIntent: ToggleAttemptIntent())
    }
}
