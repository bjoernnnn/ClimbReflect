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
    static var description = IntentDescription("Startet eine ClimbReflect-Session.")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Sportart")
    var sport: SportIntentEnum?

    @MainActor
    func perform() async throws -> some IntentResult {
        PendingStart.set(sport?.sessionTypeRaw)
        return .result()
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

// B3: Shortcut-Provider damit der Intent in Kurzbefehle + Action-Button-Liste erscheint
struct ClimbShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartSessionIntent(),
            phrases: ["Starte \(.applicationName)"],
            shortTitle: "Session starten",
            systemImageName: "figure.climbing"
        )
    }
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

    @MainActor
    func perform() async throws -> some IntentResult {
        let manager = WorkoutManager.shared
        if manager.isRunning {
            manager.handleActionButton()
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
