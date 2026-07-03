import Foundation

// FORTSCHRITT-KONZEPT: Auswertungen für den Fortschritt-Tab – Fortschritt statt
// Belastung (S31), ehrliche Statistik oder gar keine (S32). Getrennt von
// StatsEngine (Erfolge + Session-Insights). Rein funktional, unit-testbar.
//
// Grundsätze:
// - Boulder und Seil werden NIE gemischt (Discipline filtert die ganze Seite).
// - Grad-Vergleiche über canonicalOrder (S30), Anzeige über GradeConverter.display.
// - Nur isGraded-Begehungen in grad-basierten Auswertungen (RP-5).
// - Monate ohne Daten sind Lücken, keine Nullen (außer Klettertage, wo 0 echt ist).

enum ProgressEngine {

    // Zentrale Schwellen (Konzept Abschnitt 4)
    static let comfortSendQuote = 0.6
    static let minSampleSize = 5

    // MARK: - Disziplin

    enum Discipline: String, CaseIterable, Identifiable {
        case boulder, rope
        var id: String { rawValue }

        var isBoulder: Bool { self == .boulder }

        /// Boulder: Fb/V · Seil: French/UIAA
        func matches(_ ascent: Ascent) -> Bool {
            ascent.gradeSystem.isBoulder == isBoulder
        }

        /// true, wenn die Session dieser Disziplin zuzuordnen ist.
        func matches(_ session: ClimbSession) -> Bool {
            switch session.sessionType {
            case .boulder:                     return isBoulder
            case .lead, .topRope, .autoBelay:  return !isBoulder
            default:                           return false   // Training zählt nicht
            }
        }

        /// Referenz-Skala der Disziplin (Basis der kanonischen Leiter).
        var referenceSystem: GradeSystem { isBoulder ? .fontainebleau : .french }

        /// Eingestellte Anzeige-Skala (boulderScale/routeScale).
        var displaySystem: GradeSystem { GradeConverter.displaySystem(for: referenceSystem) }
    }

    // MARK: - FO-1: Bestleistungen (gesamte Historie)

    struct PersonalBest: Equatable {
        let grade: String          // bereits ins Anzeige-System konvertiert
        let system: GradeSystem    // Anzeige-System
        let date: Date
        let style: AscentStyle?
    }

    /// Höchster Send + höchster Flash (Boulder) bzw. Flash/Onsight (Seil) über die
    /// gesamte Historie. Gleichstand → frühestes Datum („zuerst erreicht").
    static func personalBests(_ sessions: [ClimbSession],
                              discipline: Discipline) -> (send: PersonalBest?, flash: PersonalBest?) {
        let tops = sessions.flatMap(\.ascents)
            .filter { discipline.matches($0) && $0.result == .top && $0.isGraded }

        let sendAscent = hardest(tops)
        let flashAscent = hardest(tops.filter { isFlashStyle($0.style, discipline: discipline) })

        return (sendAscent.map { pb($0, discipline: discipline) },
                flashAscent.map { pb($0, discipline: discipline) })
    }

    // MARK: - Interne Helfer

    /// Flash-Kriterium je Disziplin: Boulder = Flash, Seil = Flash oder Onsight.
    static func isFlashStyle(_ style: AscentStyle?, discipline: Discipline) -> Bool {
        guard let style else { return false }
        return discipline.isBoulder ? style == .flash : (style == .flash || style == .onsight)
    }

    /// Höchster canonicalOrder; bei Gleichstand die früheste Begehung.
    static func hardest(_ ascents: [Ascent]) -> Ascent? {
        ascents.reduce(nil) { best, a in
            guard let b = best else { return a }
            if a.canonicalOrder > b.canonicalOrder { return a }
            if a.canonicalOrder == b.canonicalOrder && a.date < b.date { return a }
            return b
        }
    }

    private static func pb(_ a: Ascent, discipline: Discipline) -> PersonalBest {
        PersonalBest(
            grade: GradeConverter.display(grade: a.gradeRaw, storedIn: a.gradeSystem),
            system: discipline.displaySystem,
            date: a.date,
            style: a.style
        )
    }

    // MARK: - Zeitraum-Filter

    /// Sessions ab `monthsBack` Monaten (nil = gesamte Historie).
    static func sessionsInPeriod(_ sessions: [ClimbSession], monthsBack: Int?,
                                 calendar: Calendar = .current, now: Date = Date()) -> [ClimbSession] {
        guard let monthsBack else { return sessions }
        guard let cutoff = calendar.date(byAdding: .month, value: -monthsBack, to: now) else { return sessions }
        return sessions.filter { $0.date >= cutoff }
    }
}
