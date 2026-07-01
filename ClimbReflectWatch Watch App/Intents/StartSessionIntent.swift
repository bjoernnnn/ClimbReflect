import AppIntents

// AB-3: Siri-Entry-Point („Starte ClimbReflect") – NICHT der Action-Button-Pfad
// (der läuft über StartClimbWorkoutIntent unten). AB-G: startet die Session direkt
// im Intent-Kontext statt über ein PendingStart-Flag.

struct StartSessionIntent: AppIntent {
    static var title: LocalizedStringResource = "Klettersession starten"
    static var description = IntentDescription("Startet eine ClimbReflect-Session oder trackt einen Versuch.")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Sportart")
    var sport: SportIntentEnum?

    @MainActor
    func perform() async throws -> some IntentResult {
        let manager = WorkoutManager.shared
        DiagnosticLog.shared.log("StartSessionIntent: isRunning=\(manager.isRunning) state=\(String(describing: manager.attemptState))")
        if manager.isRunning {
            // Session läuft bereits → Versuch tracken
            manager.handleActionButton()
        } else {
            // Noch keine Session → direkt starten (AB-G)
            let type = WatchSessionType(rawValue: sport?.sessionTypeRaw ?? "lead") ?? .lead
            await manager.startFromActionButton(type: type)
        }
        // Immer auf ToggleAttemptIntent wechseln (folgedrücke toggeln Versuch)
        return .result(actionButtonIntent: ToggleAttemptIntent())
    }
}

enum SportIntentEnum: String, AppEnum {
    case boulder, lead, topRope, autoBelay, training

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Sportart"
    static var caseDisplayRepresentations: [SportIntentEnum: DisplayRepresentation] = [
        .boulder:   "Bouldern",
        .lead:      "Vorstieg",
        .topRope:   "Toprope",
        .autoBelay: "Autobelay",
        .training:  "Training",
    ]

    var sessionTypeRaw: String { rawValue }
}

// MARK: - AB-3: StartClimbWorkoutIntent (StartWorkoutIntent-konform)
// Ermöglicht: Watch Einstellungen → Action Button → Fitness → ClimbReflect.
// openAppWhenRun wird durch die Protocol-Extension immer auf true gesetzt.

enum ClimbWorkoutStyle: String, AppEnum {
    case boulder, lead
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Klettern"
    static var caseDisplayRepresentations: [ClimbWorkoutStyle: DisplayRepresentation] = [
        .boulder: "Bouldern",
        .lead:    "Vorstieg",
    ]
}

struct StartClimbWorkoutIntent: StartWorkoutIntent {
    static let title: LocalizedStringResource = "Klettern"

    @Parameter(title: "Disziplin")
    var workoutStyle: ClimbWorkoutStyle

    // InstanceDisplayRepresentable
    var displayRepresentation: DisplayRepresentation {
        let label: LocalizedStringResource = workoutStyle == .boulder ? "Bouldern" : "Vorstieg"
        return DisplayRepresentation(title: label)
    }

    // CustomLocalizedStringResourceConvertible
    var localizedStringResource: LocalizedStringResource { "Klettern" }

    // StartWorkoutIntent
    static var suggestedWorkouts: [StartClimbWorkoutIntent] {
        [.init(style: .boulder), .init(style: .lead)]
    }

    // AB-A: Explizit true setzen – nötig damit der awaitingResult-Druck den
    // Klassifikations-Screen in den Vordergrund holt.
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        let manager = WorkoutManager.shared
        DiagnosticLog.shared.log("StartClimbWorkoutIntent: style=\(workoutStyle.rawValue) isRunning=\(manager.isRunning) state=\(String(describing: manager.attemptState))")
        if manager.isRunning {
            manager.handleActionButton()
        } else {
            // Keine Session läuft: direkt starten (AB-G, Default A – Idle-Fallback)
            await manager.startFromActionButton(type: workoutStyle == .boulder ? .boulder : .lead)
        }
        return .result(actionButtonIntent: ToggleAttemptIntent())
    }
}
