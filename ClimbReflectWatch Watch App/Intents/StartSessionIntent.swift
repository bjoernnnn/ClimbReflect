import AppIntents

// AB-3: StartWorkoutIntent-konformer Entry Point für den Action Button.
// Voraussetzung: Nutzer wählt ClimbReflect in Watch Einstellungen → Action Button → Fitness.
// Beim Druck (wenn keine Session läuft): App öffnen (openAppWhenRun = true).
// Beim Druck während Session: handleActionButton() + Chain auf ToggleAttemptIntent.
// B1: App Intent für den physischen Action Button (Watch Ultra).
// Ein Druck auf den zugewiesenen Action Button setzt das pendingStartFlag,
// beim nächsten App-Erscheinen startet WorkoutManager die Session automatisch.

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
            // Noch keine Session → starten
            PendingStart.set(sport?.sessionTypeRaw)
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

@available(watchOS 10.0, *)
enum ClimbWorkoutStyle: String, AppEnum {
    case boulder, lead
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Klettern"
    static var caseDisplayRepresentations: [ClimbWorkoutStyle: DisplayRepresentation] = [
        .boulder: "Bouldern",
        .lead:    "Vorstieg",
    ]
}

@available(watchOS 10.0, *)
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
            // Keine Session läuft: Session über PendingStart starten (Default A – Idle-Fallback)
            PendingStart.set(workoutStyle == .boulder ? "boulder" : "lead")
        }
        return .result(actionButtonIntent: ToggleAttemptIntent())
    }
}

// B2: Merker-Typ; WorkoutManager liest ihn beim App-Erscheinen (siehe ClimbReflectWatchApp)
enum PendingStart {
    private static let flagKey  = "pendingStartFlag"
    private static let sportKey = "pendingStartSport"

    static func set(_ raw: String?) {
        UserDefaults.standard.set(raw ?? "lead", forKey: sportKey)
        UserDefaults.standard.set(true,          forKey: flagKey)
    }

    static func consume() -> WatchSessionType? {
        guard UserDefaults.standard.bool(forKey: flagKey) else { return nil }
        UserDefaults.standard.set(false, forKey: flagKey)
        let raw = UserDefaults.standard.string(forKey: sportKey) ?? "lead"
        return WatchSessionType(rawValue: raw) ?? .lead
    }
}
