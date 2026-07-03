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

    // MARK: - FO-2: Grad-Verlauf je Monat

    struct TimelinePoint: Equatable {
        let month: Date       // 1. des Monats
        let sendOrder: Int?   // max canonicalOrder der Sends
        let flashOrder: Int?  // max canonicalOrder der Flash/Onsight-Sends
    }

    /// Härtester Send (und Flash/Onsight) je Kalendermonat. Monate ohne Sends
    /// fehlen im Array (Chart zeichnet Lücke). monthsBack == nil ⇒ gesamte Historie.
    static func gradeTimeline(_ sessions: [ClimbSession], discipline: Discipline,
                              monthsBack: Int?, calendar: Calendar = .current,
                              now: Date = Date()) -> [TimelinePoint] {
        let scoped = sessionsInPeriod(sessions, monthsBack: monthsBack, calendar: calendar, now: now)
        let tops = scoped.flatMap(\.ascents)
            .filter { discipline.matches($0) && $0.result == .top && $0.isGraded }

        var byMonth: [Date: (send: Int, flash: Int?)] = [:]
        for a in tops {
            let m = startOfMonth(a.date, calendar)
            let order = a.canonicalOrder
            var entry = byMonth[m] ?? (send: order, flash: nil)
            entry.send = max(entry.send, order)
            if isFlashStyle(a.style, discipline: discipline) {
                entry.flash = max(entry.flash ?? Int.min, order)
            }
            byMonth[m] = entry
        }
        return byMonth.keys.sorted().map { m in
            let e = byMonth[m]!
            return TimelinePoint(month: m, sendOrder: e.send, flashOrder: e.flash)
        }
    }

    /// Y-Achsen-Label: kanonischer Index → Grad-String der Anzeige-Skala.
    static func gradeLabel(forOrder order: Int, discipline: Discipline) -> String {
        guard let ref = GradeConverter.canonicalGrade(order: order, boulder: discipline.isBoulder) else { return "" }
        return GradeConverter.display(grade: ref, storedIn: discipline.referenceSystem)
    }

    static func startOfMonth(_ date: Date, _ calendar: Calendar = .current) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }

    // MARK: - FO-3: Pyramide (Zeitraum + Disziplin)

    struct PyramidRow: Equatable, Identifiable {
        let grade: String       // Anzeige-Skala
        let sends: Int
        let failedTries: Int    // Begehungen ohne Send desselben Anzeige-Grads
        let sortOrder: Int
        var id: String { grade }
    }

    /// Sends je Grad (ins Anzeige-System konvertiert), plus Begehungen ohne Send.
    /// isGraded-Filter (RP-5), disziplin-konvertierend, zeitraum-gefiltert.
    static func pyramid(_ sessions: [ClimbSession], discipline: Discipline,
                        monthsBack: Int?, calendar: Calendar = .current,
                        now: Date = Date()) -> [PyramidRow] {
        let target = discipline.displaySystem
        let scoped = sessionsInPeriod(sessions, monthsBack: monthsBack, calendar: calendar, now: now)
        let ascents = scoped.flatMap(\.ascents).filter { discipline.matches($0) && $0.isGraded }

        var groups: [String: (sends: Int, failed: Int)] = [:]
        for a in ascents {
            guard let key = GradeConverter.convert(grade: a.gradeRaw, from: a.gradeSystem, to: target)
            else { continue }   // nicht konvertierbar → ausschließen
            var e = groups[key] ?? (0, 0)
            if a.result == .top { e.sends += 1 } else { e.failed += 1 }
            groups[key] = e
        }
        return groups.compactMap { grade, c -> PyramidRow? in
            guard c.sends > 0 || c.failed > 0 else { return nil }
            let order = GradeConverter.canonicalIndex(grade: grade, system: target) ?? 0
            return PyramidRow(grade: grade, sends: c.sends, failedTries: c.failed, sortOrder: order)
        }
        .sorted { $0.sortOrder > $1.sortOrder }
    }

    // MARK: - FO-4: Wohlfühl-Grad

    /// Höchster Anzeige-Grad mit Begehungen ≥ minSampleSize und Send-Quote ≥
    /// comfortSendQuote im Zeitraum. Begehung = jeder gebankte Ascent (isGraded).
    static func comfortGrade(_ sessions: [ClimbSession], discipline: Discipline,
                             monthsBack: Int?, calendar: Calendar = .current,
                             now: Date = Date()) -> String? {
        let rows = pyramid(sessions, discipline: discipline, monthsBack: monthsBack,
                           calendar: calendar, now: now)
        let candidates = rows.filter {
            let total = $0.sends + $0.failedTries
            return total >= minSampleSize && Double($0.sends) / Double(total) >= comfortSendQuote
        }
        return candidates.max(by: { $0.sortOrder < $1.sortOrder })?.grade
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
