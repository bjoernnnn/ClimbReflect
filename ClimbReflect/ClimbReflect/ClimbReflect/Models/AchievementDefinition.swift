import Foundation

// ERFOLGE-KONZEPT-V2: statischer Katalog der "Gipfelmarken" (28 Definitionen,
// 7 Kategorien). Reine Werte-Typen, kein SwiftData-/UI-Import — die Engine
// (AchievementEngine) wertet den Katalog gegen Sessions/Projekte aus.

enum AchievementCategory: String, CaseIterable, Identifiable {
    case anfaenge, konsistenz, schwierigkeit, stil, ausdauer, projekte, momente
    var id: String { rawValue }

    var label: String {
        switch self {
        case .anfaenge:       "Anfänge"
        case .konsistenz:     "Konsistenz"
        case .schwierigkeit:  "Schwierigkeit"
        case .stil:           "Stil"
        case .ausdauer:       "Ausdauer"
        case .projekte:       "Projekte"
        case .momente:        "Momente"
        }
    }
}

enum AchievementMaterial: String, CaseIterable {
    case bronze, silber, gold, diamant
}

enum CelebrationLevel {
    case full   // Vollbild-Overlay
    case quiet  // Toast
}

/// Eine Stufe einer `tiered`-Definition. `threshold` ist bereits der aufgelöste
/// Zahlenwert (bei Grad-Leitern über `GradeConverter.canonicalIndex` abgeleitet,
/// nie hartkodiert). `name` trägt optional den Anzeige-Grad einer Grad-Stufe.
struct AchievementTier: Equatable {
    let threshold: Int
    let name: String?
    let material: AchievementMaterial
}

enum AchievementKind {
    case once(AchievementMaterial)
    case tiered([AchievementTier])
    case repeatable(AchievementMaterial)
}

struct AchievementDefinition: Identifiable {
    let id: String
    let category: AchievementCategory
    let kind: AchievementKind
    let title: String
    let criterion: String       // Detail-Sheet-Text
    let symbol: String          // SF Symbol
    let isHidden: Bool
    let celebration: CelebrationLevel
}

extension AchievementDefinition {

    /// Grad-Tiers aus Grad-Strings der Referenz-Skala ableiten (Fb bzw. French) —
    /// keine hartkodierten canonicalOrder-Indizes (S30).
    private static func gradeTiers(_ entries: [(grade: String, material: AchievementMaterial)],
                                   system: GradeSystem) -> [AchievementTier] {
        entries.map { grade, material in
            let idx = GradeConverter.canonicalIndex(grade: grade, system: system) ?? 0
            return AchievementTier(threshold: idx, name: grade, material: material)
        }
    }

    private static func numberTiers(_ entries: [(threshold: Int, material: AchievementMaterial)]) -> [AchievementTier] {
        entries.map { AchievementTier(threshold: $0.threshold, name: nil, material: $0.material) }
    }

    static let all: [AchievementDefinition] = [

        // MARK: 1 · Anfänge

        AchievementDefinition(
            id: "first_session", category: .anfaenge, kind: .once(.bronze),
            title: "Seil frei", criterion: "Erste Session aufgezeichnet.",
            symbol: "flag.fill", isHidden: false, celebration: .full),
        AchievementDefinition(
            id: "first_top", category: .anfaenge, kind: .once(.bronze),
            title: "Erster Top", criterion: "Erste Begehung mit Ergebnis Top.",
            symbol: "checkmark.seal.fill", isHidden: false, celebration: .full),
        AchievementDefinition(
            id: "first_reflection", category: .anfaenge, kind: .once(.bronze),
            title: "Innehalten", criterion: "Erste Reflexion nach einer Session abgeschlossen.",
            symbol: "book.closed.fill", isHidden: false, celebration: .full),
        AchievementDefinition(
            id: "first_outdoor", category: .anfaenge, kind: .once(.silber),
            title: "Ans echte Gestein", criterion: "Erste Outdoor-Session.",
            symbol: "sun.max.fill", isHidden: false, celebration: .full),
        AchievementDefinition(
            id: "discipline_trio", category: .anfaenge, kind: .once(.silber),
            title: "Dreiklang",
            criterion: "Mindestens eine Session in 3 von 4 Kletter-Disziplinen (Boulder, Vorstieg, Toprope, Autobelay).",
            symbol: "3.circle.fill", isHidden: false, celebration: .full),

        // MARK: 2 · Konsistenz

        AchievementDefinition(
            id: "week_streak", category: .konsistenz,
            kind: .tiered(numberTiers([
                (4, .bronze), (8, .bronze), (13, .silber), (26, .gold), (52, .diamant)
            ])),
            title: "Am Ball",
            criterion: "Wochen in Folge mit mindestens einer Session. Die laufende, noch leere Woche verzeiht.",
            symbol: "flame.fill", isHidden: false, celebration: .full),
        AchievementDefinition(
            id: "sessions_total", category: .konsistenz,
            kind: .tiered(numberTiers([
                (10, .bronze), (25, .bronze), (50, .silber), (100, .gold), (250, .diamant)
            ])),
            title: "Stammgast", criterion: "Sessions gesamt.",
            symbol: "calendar", isHidden: false, celebration: .full),
        AchievementDefinition(
            id: "climb_days_year", category: .konsistenz, kind: .repeatable(.gold),
            title: "Jahr der Wand",
            criterion: "Mindestens 50 Klettertage in einem Kalenderjahr.",
            symbol: "calendar.circle.fill", isHidden: false, celebration: .full),
        AchievementDefinition(
            id: "comeback", category: .konsistenz, kind: .once(.silber),
            title: "Wieder da", criterion: "Klettersession nach mindestens 30 Tagen Pause.",
            symbol: "arrow.up.heart.fill", isHidden: false, celebration: .full),

        // MARK: 3 · Schwierigkeit

        AchievementDefinition(
            id: "pb_boulder", category: .schwierigkeit, kind: .repeatable(.gold),
            title: "Neue Bestmarke", criterion: "Neuer Boulder-Höchstgrad.",
            symbol: "star.fill", isHidden: false, celebration: .full),
        AchievementDefinition(
            id: "pb_route", category: .schwierigkeit, kind: .repeatable(.gold),
            title: "Neue Bestmarke", criterion: "Neuer Seil-Höchstgrad.",
            symbol: "star.fill", isHidden: false, celebration: .full),
        AchievementDefinition(
            id: "grade_boulder", category: .schwierigkeit,
            kind: .tiered(gradeTiers([
                ("6A", .bronze), ("6C", .silber), ("7A", .gold), ("7C", .gold), ("8A", .diamant)
            ], system: .fontainebleau)),
            title: "Boulder-Meilensteine", criterion: "Erster Boulder-Top ab kanonischem Grad.",
            symbol: "mountain.2.fill", isHidden: false, celebration: .full),
        AchievementDefinition(
            id: "grade_route", category: .schwierigkeit,
            kind: .tiered(gradeTiers([
                ("6a", .bronze), ("6c", .silber), ("7a", .gold), ("7c+", .gold), ("8a", .diamant)
            ], system: .french)),
            title: "Routen-Meilensteine", criterion: "Erster Seil-Top ab kanonischem Grad.",
            symbol: "arrow.up.right.circle.fill", isHidden: false, celebration: .full),

        // MARK: 4 · Stil

        AchievementDefinition(
            id: "flash_total", category: .stil,
            kind: .tiered(numberTiers([(5, .bronze), (25, .silber), (100, .gold)])),
            title: "Blitzsammler", criterion: "Flash-Tops gesamt.",
            symbol: "bolt.fill", isHidden: false, celebration: .full),
        AchievementDefinition(
            id: "onsight_total", category: .stil,
            kind: .tiered(numberTiers([(1, .silber), (10, .gold), (25, .gold)])),
            title: "Auf Sicht", criterion: "Onsight-Tops gesamt.",
            symbol: "eye.fill", isHidden: false, celebration: .full),
        AchievementDefinition(
            id: "flash_day", category: .stil, kind: .repeatable(.silber),
            title: "Lauf", criterion: "Mindestens 3 Flashes in einer Session.",
            symbol: "bolt.circle.fill", isHidden: false, celebration: .quiet),
        AchievementDefinition(
            id: "angle_allrounder", category: .stil, kind: .once(.gold),
            title: "Allrounder",
            criterion: "Tops in allen 4 Wandwinkeln (Platte, Senkrecht, Überhang, Dach).",
            symbol: "cube.fill", isHidden: false, celebration: .full),

        // MARK: 5 · Ausdauer

        AchievementDefinition(
            id: "tops_total", category: .ausdauer,
            kind: .tiered(numberTiers([
                (10, .bronze), (50, .bronze), (100, .silber), (250, .gold), (500, .gold), (1000, .diamant)
            ])),
            title: "Gipfelsammler", criterion: "Getoppte Begehungen gesamt.",
            symbol: "mountain.2.fill", isHidden: false, celebration: .full),
        AchievementDefinition(
            id: "hours_total", category: .ausdauer,
            kind: .tiered(numberTiers([
                (10, .bronze), (25, .silber), (50, .silber), (100, .gold), (250, .diamant)
            ])),
            title: "Stunden an der Wand", criterion: "Aktive Kletterstunden gesamt.",
            symbol: "clock.fill", isHidden: false, celebration: .full),
        AchievementDefinition(
            id: "altitude_total", category: .ausdauer,
            kind: .tiered(numberTiers([
                (100, .bronze), (500, .silber), (1000, .gold), (8848, .diamant)
            ])),
            title: "Höhenmeter",
            criterion: "Kumulierte, per Watch-Barometer gemessene Kletterhöhenmeter. Stufe IV ist der Everest.",
            symbol: "arrow.up.to.line", isHidden: false, celebration: .full),
        AchievementDefinition(
            id: "big_day", category: .ausdauer, kind: .repeatable(.silber),
            title: "Marathon-Tag", criterion: "Mindestens 20 Tops in einer Session.",
            symbol: "sparkles", isHidden: false, celebration: .quiet),

        // MARK: 6 · Projekte

        AchievementDefinition(
            id: "project_first_send", category: .projekte, kind: .once(.silber),
            title: "Der Prozess", criterion: "Erstes Projekt gesendet.",
            symbol: "target", isHidden: false, celebration: .full),
        AchievementDefinition(
            id: "projects_total", category: .projekte,
            kind: .tiered(numberTiers([(3, .silber), (10, .gold), (25, .gold)])),
            title: "Projektjäger", criterion: "Gesendete Projekte gesamt.",
            symbol: "target", isHidden: false, celebration: .full),
        AchievementDefinition(
            id: "project_persistent", category: .projekte, kind: .repeatable(.gold),
            title: "Hartnäckig",
            criterion: "Ein Projekt mit mindestens 10 gebuchten Begehungen gesendet.",
            symbol: "repeat.circle.fill", isHidden: false, celebration: .full),
        AchievementDefinition(
            id: "project_longgame", category: .projekte, kind: .once(.gold),
            title: "Langes Spiel",
            criterion: "Ein Projekt über mindestens 3 verschiedene Klettertage gesendet.",
            symbol: "hourglass", isHidden: false, celebration: .full),

        // MARK: 7 · Besondere Momente (verborgen)

        AchievementDefinition(
            id: "dawn_patrol", category: .momente, kind: .once(.silber),
            title: "Frühschicht", criterion: "Session vor 7:00 Uhr gestartet.",
            symbol: "sunrise.fill", isHidden: true, celebration: .full),
        AchievementDefinition(
            id: "grade_leap", category: .momente, kind: .once(.gold),
            title: "Quantensprung",
            criterion: "Neue Bestmarke, die den alten Höchstgrad um mindestens 2 kanonische Stufen überspringt.",
            symbol: "arrow.up.right.circle.fill", isHidden: true, celebration: .full),
        AchievementDefinition(
            id: "new_year_climb", category: .momente, kind: .once(.silber),
            title: "Guter Vorsatz", criterion: "Session am 1. Januar.",
            symbol: "party.popper.fill", isHidden: true, celebration: .full),
    ]

    static func definition(id: String) -> AchievementDefinition? {
        all.first { $0.id == id }
    }
}
