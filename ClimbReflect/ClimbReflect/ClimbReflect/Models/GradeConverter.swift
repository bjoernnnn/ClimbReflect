import Foundation

// Verlustfreie Grad-Umrechnung über einen gemeinsamen Index pro Disziplin.
// Boulder: Fb ↔ V-Scale  |  Route: French ↔ UIAA
// Verschiedene Disziplinen werden NICHT ineinander umgerechnet.

enum GradeConverter {

    // MARK: - Boulder-Leiter (gemeinsamer Index 0…)

    private static let boulderFb: [String] = [
        "3", "4", "4+", "5", "5+",
        "6A", "6A+", "6B", "6B+", "6C", "6C+",
        "7A", "7A+", "7B", "7B+", "7C", "7C+",
        "8A", "8A+", "8B", "8B+", "8C", "8C+", "9A"
    ]

    private static let boulderV: [String] = [
        "VB", "V0", "V0+", "V1", "V2",
        "V3", "V3", "V4", "V4", "V5", "V5",
        "V6", "V7", "V8", "V8", "V9", "V10",
        "V11", "V12", "V13", "V13", "V14", "V15", "V17"
    ]

    // MARK: - Routen-Leiter (gemeinsamer Index 0…)

    private static let routeFrench: [String] = [
        "4", "4+", "5a", "5b", "5c",
        "6a", "6a+", "6b", "6b+", "6c", "6c+",
        "7a", "7a+", "7b", "7b+", "7c", "7c+",
        "8a", "8a+", "8b", "8b+", "8c", "8c+", "9a"
    ]

    private static let routeUIAA: [String] = [
        "IV", "IV+", "V-", "V", "V+",
        "VI-", "VI", "VI+", "VII-", "VII", "VII+",
        "VIII-", "VIII", "VIII+", "IX-", "IX", "IX+",
        "X-", "X", "X+", "XI-", "XI", "XI+", "XII"
    ]

    // MARK: - Öffentliche API

    /// Konvertiert `grade` aus `from`-System in `to`-System.
    /// Gibt nil zurück wenn die Systeme nicht kompatibel sind
    /// (z. B. Boulder→Route) oder der Grad nicht in der Leiter liegt.
    static func convert(grade: String, from: GradeSystem, to: GradeSystem) -> String? {
        guard from != to else { return grade }

        switch (from, to) {
        // Boulder
        case (.fontainebleau, .vScale):
            return lookup(grade, in: boulderFb, out: boulderV)
        case (.vScale, .fontainebleau):
            return lookup(grade, in: boulderV, out: boulderFb)
        // Route
        case (.french, .uiaa):
            return lookup(grade, in: routeFrench, out: routeUIAA)
        case (.uiaa, .french):
            return lookup(grade, in: routeUIAA, out: routeFrench)
        default:
            return nil
        }
    }

    /// Konvertiert zum Anzeige-System das in AppStorage gespeichert ist.
    /// Liest `boulderScale` / `routeScale` aus UserDefaults.
    static func display(grade: String, storedIn system: GradeSystem) -> String {
        let isBoulder = (system == .fontainebleau || system == .vScale)
        let targetRaw = isBoulder
            ? (UserDefaults.standard.string(forKey: "boulderScale") ?? GradeSystem.fontainebleau.rawValue)
            : (UserDefaults.standard.string(forKey: "routeScale") ?? GradeSystem.french.rawValue)
        guard let target = GradeSystem(rawValue: targetRaw) else { return grade }
        return convert(grade: grade, from: system, to: target) ?? grade
    }

    // MARK: - Intern

    private static func lookup(_ grade: String, in source: [String], out target: [String]) -> String? {
        guard let idx = source.firstIndex(of: grade), idx < target.count else { return nil }
        return target[idx]
    }
}
