import AppIntents

// AB-3: Siri-Entry-Point („Starte ClimbReflect") – NICHT der Action-Button-Pfad
// (der läuft über StartClimbWorkoutIntent unten). AB-G: startet die Session direkt
// im Intent-Kontext statt über ein PendingStart-Flag.
//
// AB-K: ALLE Intent-Typen und AppEnums sind explizit `nonisolated`.
// Das Projekt baut mit SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor – damit wären
// init()/Parameter-Dekodierung/statische Properties implizit MainActor-isoliert.
// Die AppIntents-Runtime instanziiert und dekodiert Intents aber ABSEITS des
// Main-Threads → der dynamische Isolations-Check crasht den Prozess, BEVOR
// perform() (und damit unser Log) erreicht wird. Sichtbares Fehlerbild:
// Kurzbefehl „schlägt fehl", Action Button zeigt nur den orangen Screen.
// perform() bleibt @MainActor (WorkoutManager/DiagnosticLog sind MainActor).

nonisolated struct StartSessionIntent: AppIntent {
    static let title: LocalizedStringResource = "Klettersession starten"
    static let description = IntentDescription("Startet eine ClimbReflect-Session oder trackt einen Versuch.")
    static let openAppWhenRun: Bool = true

    @Parameter(title: "Sportart")
    var sport: SportIntentEnum?

    @MainActor
    func perform() async throws -> some IntentResult {
        let manager = WorkoutManager.shared
        // flushImmediately: Beweis auf Disk, auch wenn der Prozess direkt danach stirbt
        DiagnosticLog.shared.log("StartSessionIntent: isRunning=\(manager.isRunning) state=\(String(describing: manager.attemptState))", flushImmediately: true)
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

nonisolated enum SportIntentEnum: String, AppEnum {
    case boulder, lead, topRope, autoBelay, training

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Sportart"
    static let caseDisplayRepresentations: [SportIntentEnum: DisplayRepresentation] = [
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

nonisolated enum ClimbWorkoutStyle: String, AppEnum {
    case boulder, lead
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Klettern"
    static let caseDisplayRepresentations: [ClimbWorkoutStyle: DisplayRepresentation] = [
        .boulder: "Bouldern",
        .lead:    "Vorstieg",
    ]
}

nonisolated struct StartClimbWorkoutIntent: StartWorkoutIntent {
    static let title: LocalizedStringResource = "Klettern"

    @Parameter(title: "Disziplin")
    var workoutStyle: ClimbWorkoutStyle

    // AB-I: Expliziter Default wie im Referenzprojekt (KhaosT). Ohne Default traps
    // der Zugriff auf einen nicht injizierten @Parameter noch VOR der ersten
    // Log-Zeile → stiller Crash beim Action-Button-Druck (oranger Screen, kein Log).
    init() {
        self.workoutStyle = .lead
    }

    init(style: ClimbWorkoutStyle) {
        self.workoutStyle = style
    }

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
    static let openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        let manager = WorkoutManager.shared
        // flushImmediately: Beweis auf Disk, auch wenn der Prozess direkt danach stirbt
        DiagnosticLog.shared.log("StartClimbWorkoutIntent: style=\(workoutStyle.rawValue) isRunning=\(manager.isRunning) state=\(String(describing: manager.attemptState))", flushImmediately: true)
        if manager.isRunning {
            manager.handleActionButton()
        } else {
            // Keine Session läuft: direkt starten (AB-G, Default A – Idle-Fallback)
            await manager.startFromActionButton(type: workoutStyle == .boulder ? .boulder : .lead)
        }
        return .result(actionButtonIntent: ToggleAttemptIntent())
    }
}

// MARK: - AB-J: Siri-/Kurzbefehle-Zugang zum SELBEN Workout-Intent
// Diagnose- und Alternativ-Pfad: löst exakt dieselbe Kette aus wie der Action
// Button (StartClimbWorkoutIntent → ToggleAttemptIntent-Chain), nur über
// Siri/Kurzbefehle statt Hardware. Loggt der Kurzbefehl, aber der Button nicht,
// ist die Button-Zustellung des Systems defekt – nicht unsere App.
// ACHTUNG (S23): In den Action-Button-Settings weiterhin den WORKOUT-Pfad
// (Training → Vorstieg/Bouldern) wählen, NICHT den App-Shortcut.

nonisolated struct ClimbShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartClimbWorkoutIntent(style: .lead),
            phrases: [
                "Starte \(.applicationName)",
                "Klettern starten mit \(.applicationName)",
            ],
            shortTitle: "Klettern starten",
            systemImageName: "figure.climbing"
        )
    }
}

// MARK: - AB-I: Pause/Resume-Workout-Intents (Referenz-Parität)
// Das Referenzprojekt registriert Pause/Resume mit – Teil der vollständigen
// Workout-App-Integration; System kann sie z. B. aus Workout-Controls aufrufen.

nonisolated struct PauseClimbWorkoutIntent: PauseWorkoutIntent {
    static let title: LocalizedStringResource = "Pause"

    @MainActor
    func perform() async throws -> some IntentResult {
        let manager = WorkoutManager.shared
        DiagnosticLog.shared.log("PauseClimbWorkoutIntent: isRunning=\(manager.isRunning)", flushImmediately: true)
        if manager.isRunning && !manager.isPaused { manager.pauseWorkout() }
        return .result()
    }
}

nonisolated struct ResumeClimbWorkoutIntent: ResumeWorkoutIntent {
    static let title: LocalizedStringResource = "Fortsetzen"

    @MainActor
    func perform() async throws -> some IntentResult {
        let manager = WorkoutManager.shared
        DiagnosticLog.shared.log("ResumeClimbWorkoutIntent: isRunning=\(manager.isRunning)", flushImmediately: true)
        if manager.isRunning && manager.isPaused { manager.resumeWorkout() }
        return .result()
    }
}
