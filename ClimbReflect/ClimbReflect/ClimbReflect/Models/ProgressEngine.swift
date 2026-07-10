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
        let order: Int             // MO-3: canonicalOrder der Begehung (für nextGrade)
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
            style: a.style,
            order: a.canonicalOrder
        )
    }

    // MARK: - MO-3: Nächste Leiterstufe

    /// Anzeige-Grad der kanonischen Stufe direkt über `order`;
    /// nil am Leiter-Ende (gradeLabel liefert dort "").
    static func nextGrade(afterOrder order: Int,
                          discipline: Discipline) -> String? {
        let label = gradeLabel(forOrder: order + 1, discipline: discipline)
        return label.isEmpty ? nil : label
    }

    // MARK: - MO-2: Zeitraum-Highlights (Erst-Sends + Bestwert)

    /// Ein Grad, der im Zeitraum zum ersten Mal überhaupt gesendet wurde.
    struct FirstSend: Equatable, Identifiable {
        let grade: String   // Anzeige-Skala
        let order: Int      // canonical, für Sortierung
        let date: Date      // frühester Send dieses Grads überhaupt
        var id: String { grade }
    }

    /// Neuigkeiten eines Zeitraums: erstmals gesendete Grade + härtester Send
    /// im Zeitraum (mit Kennzeichnung, ob er zugleich der historische PB ist).
    struct Highlights: Equatable {
        let firstSends: [FirstSend]      // absteigend nach order
        let hardestSend: PersonalBest?   // härtester Send IM Zeitraum
        let isAllTimeBest: Bool          // == historischer PB?
    }

    /// Erst-Sends und Zeitraum-Bestwert für den „Was ist neu?"-Hebel.
    /// Ein Erst-Send ist ein Anzeige-Grad, dessen frühestes Send-Datum der
    /// GESAMTEN Historie im Zeitraum liegt – das ehrlichste Neuheits-Signal des
    /// Bestands, ganz ohne Persistenz oder Prognose.
    ///
    /// `monthsBack == nil` liefert bewusst KEINE Erst-Sends: über die
    /// Gesamthistorie ist jeder je gesendete Grad trivial ein „Erst-Send", die
    /// Zeile wäre reines Rauschen (Konsens-Punkt 2). Die UI zeigt die Highlights-
    /// Zeile darum nur bei endlichem Zeitraum.
    static func periodHighlights(_ sessions: [ClimbSession],
                                 discipline: Discipline, monthsBack: Int?,
                                 calendar: Calendar = .current,
                                 now: Date = Date()) -> Highlights {
        let allTops = sessions.flatMap(\.ascents)
            .filter { discipline.matches($0) && $0.result == .top && $0.isGraded }
        guard !allTops.isEmpty else {
            return Highlights(firstSends: [], hardestSend: nil, isAllTimeBest: false)
        }
        let target = discipline.displaySystem

        // Erst-Sends nur bei endlichem Zeitraum (siehe Doc-Kommentar).
        var firstSends: [FirstSend] = []
        if let monthsBack,
           let cutoff = calendar.date(byAdding: .month, value: -monthsBack, to: now) {
            // Je Anzeige-Grad das früheste Send-Datum der Gesamthistorie
            // (Konvertierung wie pyramid → ein V-Scale-Send nach gleichwertiger
            //  Font-Historie fällt in denselben Topf, ist also kein Erst-Send).
            var earliest: [String: Date] = [:]
            for a in allTops {
                guard let key = GradeConverter.convert(grade: a.gradeRaw, from: a.gradeSystem, to: target)
                else { continue }   // nicht konvertierbar → ausschließen
                earliest[key] = earliest[key].map { min($0, a.date) } ?? a.date
            }
            firstSends = earliest.compactMap { grade, date -> FirstSend? in
                guard date >= cutoff else { return nil }
                let order = GradeConverter.canonicalIndex(grade: grade, system: target) ?? 0
                return FirstSend(grade: grade, order: order, date: date)
            }
            .sorted { $0.order > $1.order }   // absteigend nach order
        }

        // Härtester Send im Zeitraum + Abgleich mit historischem Maximum.
        let scopedTops = sessionsInPeriod(sessions, monthsBack: monthsBack,
                                          calendar: calendar, now: now)
            .flatMap(\.ascents)
            .filter { discipline.matches($0) && $0.result == .top && $0.isGraded }
        let hardestInPeriod = hardest(scopedTops)
        let allTimeMax = allTops.map(\.canonicalOrder).max() ?? Int.min
        return Highlights(
            firstSends: firstSends,
            hardestSend: hardestInPeriod.map { pb($0, discipline: discipline) },
            isAllTimeBest: hardestInPeriod.map { $0.canonicalOrder == allTimeMax } ?? false
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

    // MARK: - FO-5: Klettertage & Zeitraum-Kennzahlen

    /// Eindeutige Klettertage je Monat (letzte `monthsBack` Monate inkl. aktuellem),
    /// disziplin-gefiltert. Monate ohne Tage = 0 (hier sind Nullen eine echte Aussage).
    static func climbDaysPerMonth(_ sessions: [ClimbSession], discipline: Discipline,
                                  monthsBack: Int = 6, calendar: Calendar = .current,
                                  now: Date = Date()) -> [(month: Date, days: Int)] {
        var result: [(month: Date, days: Int)] = []
        for offset in stride(from: monthsBack - 1, through: 0, by: -1) {
            guard let ref = calendar.date(byAdding: .month, value: -offset, to: now) else { continue }
            let monthStart = startOfMonth(ref, calendar)
            guard let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else { continue }
            let days = Set(sessions
                .filter { discipline.matches($0) && $0.date >= monthStart && $0.date < monthEnd }
                .map { calendar.startOfDay(for: $0.date) })
            result.append((monthStart, days.count))
        }
        return result
    }

    /// Sends (Tops der Disziplin) + eindeutige Klettertage im Zeitraum.
    static func periodTotals(_ sessions: [ClimbSession], discipline: Discipline,
                             monthsBack: Int?, calendar: Calendar = .current,
                             now: Date = Date()) -> (sends: Int, climbDays: Int) {
        let scoped = sessionsInPeriod(sessions, monthsBack: monthsBack, calendar: calendar, now: now)
            .filter { discipline.matches($0) }
        let sends = scoped.flatMap(\.ascents)
            .filter { discipline.matches($0) && $0.result == .top }.count
        let days = Set(scoped.map { calendar.startOfDay(for: $0.date) }).count
        return (sends, days)
    }

    // MARK: - FO-6: Stil-Quoten & Limiter (mit Mindest-n)

    struct StyleRate: Equatable, Identifiable {
        let label: String
        let category: String   // "Wandwinkel" | "Grifftyp" | "Kletterart"
        let sendRate: Double   // 0…1
        let sample: Int
        var id: String { "\(category)_\(label)" }
    }

    /// Send-Quoten je Stil-Merkmal der Disziplin. Nur Gruppen mit Stichprobe
    /// ≥ minSampleSize (S32: keine Ein-Begehung-Quoten), schwächste zuerst.
    static func styleRates(_ sessions: [ClimbSession], discipline: Discipline,
                           monthsBack: Int?, calendar: Calendar = .current,
                           now: Date = Date()) -> [StyleRate] {
        let scoped = sessionsInPeriod(sessions, monthsBack: monthsBack, calendar: calendar, now: now)
            .filter { $0.isClimbing }
        let ascents = scoped.flatMap(\.ascents).filter { discipline.matches($0) }

        func rates<T: Hashable>(_ cases: [T], _ category: String,
                                key: (Ascent) -> T?, label: (T) -> String) -> [StyleRate] {
            cases.compactMap { c in
                let group = ascents.filter { key($0) == c }
                guard group.count >= minSampleSize else { return nil }
                let tops = group.filter { $0.result == .top }.count
                return StyleRate(label: label(c), category: category,
                                 sendRate: Double(tops) / Double(group.count), sample: group.count)
            }
        }

        var result: [StyleRate] = []
        result += rates(WallAngle.allCases, "Wandwinkel", key: { $0.wallAngle }, label: { $0.label })
        result += rates(HoldType.allCases, "Grifftyp", key: { $0.holdType }, label: { $0.label })
        result += rates(ClimbStyle.allCases, "Kletterart", key: { $0.climbStyle }, label: { $0.label })
        return result.sorted { $0.sendRate < $1.sendRate }   // Schwächen zuerst
    }

    /// Häufigste Limiter über alle Kletter-Sessions im Zeitraum. Disziplin-übergreifend
    /// (Limiter hängen an der Session, nicht am Grad), absteigend nach Anzahl.
    static func limiterCounts(_ sessions: [ClimbSession], monthsBack: Int?,
                              calendar: Calendar = .current,
                              now: Date = Date()) -> [(limiter: Limiter, count: Int)] {
        let scoped = sessionsInPeriod(sessions, monthsBack: monthsBack, calendar: calendar, now: now)
            .filter { $0.isClimbing }
        var counts: [Limiter: Int] = [:]
        for s in scoped { for l in s.limiters { counts[l, default: 0] += 1 } }
        return counts.map { (limiter: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    // MARK: - MO-4: Endowed Progress (Stil-Gruppen unter der Schwelle + Kandidat)

    struct PendingStyle: Equatable, Identifiable {
        let label: String
        let category: String        // wie StyleRate
        let sample: Int             // 1 ≤ sample < minSampleSize
        var id: String { "\(category)_\(label)" }
    }

    /// Stil-Gruppen knapp unter der Auswertungs-Schwelle (1 ≤ n < minSampleSize).
    /// Endowed-Progress-Hebel: transportiert bewusst nur die Stichprobe, KEINE
    /// Send-Quote (die wäre unter n = 5 nicht belastbar, S32). Gleiche Gruppierung
    /// wie `styleRates`; Sortierung nach Stichprobe absteigend (nächstgelegene zuerst).
    static func stylePendingGroups(_ sessions: [ClimbSession], discipline: Discipline,
                                   monthsBack: Int?, calendar: Calendar = .current,
                                   now: Date = Date()) -> [PendingStyle] {
        let scoped = sessionsInPeriod(sessions, monthsBack: monthsBack, calendar: calendar, now: now)
            .filter { $0.isClimbing }
        let ascents = scoped.flatMap(\.ascents).filter { discipline.matches($0) }

        func pending<T: Hashable>(_ cases: [T], _ category: String,
                                  key: (Ascent) -> T?, label: (T) -> String) -> [PendingStyle] {
            cases.compactMap { c in
                let count = ascents.filter { key($0) == c }.count
                guard count >= 1 && count < minSampleSize else { return nil }
                return PendingStyle(label: label(c), category: category, sample: count)
            }
        }

        var result: [PendingStyle] = []
        result += pending(WallAngle.allCases, "Wandwinkel", key: { $0.wallAngle }, label: { $0.label })
        result += pending(HoldType.allCases, "Grifftyp", key: { $0.holdType }, label: { $0.label })
        result += pending(ClimbStyle.allCases, "Kletterart", key: { $0.climbStyle }, label: { $0.label })
        return result.sorted { $0.sample > $1.sample }
    }

    /// Wohlfühl-Grad-Kandidat, solange `comfortGrade` nil ist: die Pyramiden-Zeile
    /// mit 1 ≤ total < minSampleSize, priorisiert nach (total, dann sortOrder).
    /// Nur Stichprobe, keine Quote (S32).
    static func comfortCandidate(_ sessions: [ClimbSession], discipline: Discipline,
                                 monthsBack: Int?, calendar: Calendar = .current,
                                 now: Date = Date()) -> (grade: String, sample: Int)? {
        let rows = pyramid(sessions, discipline: discipline, monthsBack: monthsBack,
                           calendar: calendar, now: now)
        let candidates = rows.compactMap { row -> (grade: String, sample: Int, sortOrder: Int)? in
            let total = row.sends + row.failedTries
            guard total >= 1 && total < minSampleSize else { return nil }
            return (row.grade, total, row.sortOrder)
        }
        guard let best = candidates.max(by: {
            $0.sample != $1.sample ? $0.sample < $1.sample : $0.sortOrder < $1.sortOrder
        }) else { return nil }
        return (best.grade, best.sample)
    }

    // MARK: - FO-14: Wochen-Zählung (entkoppelt von weeklyMinutes)

    /// Anzahl Kletter-Sessions in der laufenden Kalenderwoche (Montag-Start).
    /// Ersetzt die Kopplung der Today-Kachel an die gelöschte `weeklyMinutes`.
    static func sessionsThisWeek(_ sessions: [ClimbSession], calendar: Calendar = .current,
                                 now: Date = Date()) -> Int {
        var cal = calendar
        cal.firstWeekday = 2
        guard let week = cal.dateInterval(of: .weekOfYear, for: now) else { return 0 }
        return sessions.filter { $0.isClimbing && week.contains($0.date) }.count
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
