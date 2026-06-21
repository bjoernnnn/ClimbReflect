import AppIntents

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
