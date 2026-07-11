import Foundation

// ERFOLGE-KONZEPT-V2: reine Auswertungs-Engine über den AchievementDefinition-
// Katalog. Kein SwiftData-/UI-Import — Sessions/Projekte rein, PendingUnlocks/
// Progress raus (Muster: ProgressEngine). `evaluate` rekonstruiert bei jedem
// Aufruf die VOLLSTÄNDIGE Historie aller je erreichten Ereignisse (nicht nur
// neue) — Idempotenz entsteht durch den `existing`-Abgleich des Aufrufers
// (AchievementService), nicht durch Engine-internen Zustand.

enum AchievementEngine {

    struct PendingUnlock: Equatable {
        let definitionID: String
        let tier: Int?          // Index in AchievementTier-Array (0-basiert)
        let date: Date
        let contextValue: String?
        let sessionID: UUID?
    }

    struct ExistingUnlockKey: Hashable {
        let definitionID: String
        let tier: Int?
        let contextValue: String?
        let sessionID: UUID?
    }

    struct AchievementProgress {
        let fraction: Double    // 0...1
        let current: Int
        let target: Int
        let remainingText: String
    }

    // MARK: - Öffentliche API

    static func evaluate(sessions: [ClimbSession], projects: [Project],
                         existing: Set<ExistingUnlockKey>,
                         calendar: Calendar = .current, now: Date = Date()) -> [PendingUnlock] {
        let all = allEvents(sessions: sessions, projects: projects, calendar: calendar, now: now)
        return all.filter { !existing.contains(key(for: $0)) }
    }

    static func progress(for definitionID: String, sessions: [ClimbSession], projects: [Project],
                         calendar: Calendar = .current, now: Date = Date()) -> AchievementProgress? {
        guard let def = AchievementDefinition.definition(id: definitionID) else { return nil }

        switch def.kind {
        case .tiered(let tiers):
            guard let current = currentTieredValue(definitionID, sessions: sessions, projects: projects,
                                                    calendar: calendar) else { return nil }
            guard let next = tiers.first(where: { $0.threshold > current }) else { return nil }  // höchste Stufe erreicht
            let fraction = next.threshold > 0 ? min(1, Double(current) / Double(next.threshold)) : 0
            return AchievementProgress(fraction: fraction, current: current, target: next.threshold,
                                       remainingText: remainingText(definitionID, current: current, target: next.threshold))

        case .once:
            guard let (current, target) = onceProgressValue(definitionID, sessions: sessions, projects: projects)
            else { return nil }
            let fraction = target > 0 ? min(1, Double(current) / Double(target)) : 0
            return AchievementProgress(fraction: fraction, current: current, target: target,
                                       remainingText: remainingText(definitionID, current: current, target: target))

        case .repeatable:
            guard definitionID == "climb_days_year" else { return nil }
            let year = calendar.component(.year, from: now)
            let days = climbDaysInYear(sessions, year: year, calendar: calendar)
            let target = 50
            let fraction = min(1, Double(days) / Double(target))
            return AchievementProgress(fraction: fraction, current: days, target: target,
                                       remainingText: remainingText(definitionID, current: days, target: target))
        }
    }

    // MARK: - Idempotenz-Schlüssel

    private static func key(for u: PendingUnlock) -> ExistingUnlockKey {
        ExistingUnlockKey(definitionID: u.definitionID, tier: u.tier,
                         contextValue: u.tier == nil ? u.contextValue : nil,
                         sessionID: u.tier == nil ? u.sessionID : nil)
    }

    // MARK: - Gesamte Ereignis-Historie (alle Definitionen)

    private static func allEvents(sessions: [ClimbSession], projects: [Project],
                                  calendar: Calendar, now: Date) -> [PendingUnlock] {
        var out: [PendingUnlock] = []

        // Anfänge
        if let e = firstSessionEvent(sessions) { out.append(e) }
        if let e = firstTopEvent(sessions) { out.append(e) }
        if let e = firstReflectionEvent(sessions) { out.append(e) }
        if let e = firstOutdoorEvent(sessions) { out.append(e) }
        if let e = disciplineTrioEvent(sessions) { out.append(e) }

        // Konsistenz
        out += weekStreakEvents(sessions, calendar: calendar)
        out += sessionsTotalEvents(sessions)
        out += climbDaysYearEvents(sessions, calendar: calendar)
        if let e = comebackEvent(sessions, calendar: calendar) { out.append(e) }

        // Schwierigkeit
        out += pbEvents(sessions, definitionID: "pb_boulder", boulder: true)
        out += pbEvents(sessions, definitionID: "pb_route", boulder: false)
        out += gradeMilestoneEvents(sessions, definitionID: "grade_boulder", boulder: true)
        out += gradeMilestoneEvents(sessions, definitionID: "grade_route", boulder: false)

        // Stil
        out += flashOnsightTotalEvents(sessions, definitionID: "flash_total", style: .flash)
        out += flashOnsightTotalEvents(sessions, definitionID: "onsight_total", style: .onsight)
        out += flashDayEvents(sessions)
        if let e = angleAllrounderEvent(sessions) { out.append(e) }

        // Ausdauer
        out += topsTotalEvents(sessions)
        out += hoursTotalEvents(sessions)
        out += altitudeTotalEvents(sessions)
        out += bigDayEvents(sessions)

        // Projekte
        let sentChron = sentProjectsChronological(projects)
        if let first = sentChron.first {
            out.append(PendingUnlock(definitionID: "project_first_send", tier: nil, date: first.date,
                                     contextValue: nil, sessionID: first.sessionID))
        }
        out += projectsTotalEvents(sentChron)
        out += projectPersistentEvents(sentChron)
        if let e = projectLonggameEvent(sentChron) { out.append(e) }

        // Besondere Momente
        if let e = dawnPatrolEvent(sessions, calendar: calendar) { out.append(e) }
        if let e = gradeLeapEvent(sessions) { out.append(e) }
        if let e = newYearClimbEvent(sessions, calendar: calendar) { out.append(e) }

        return out
    }

    // MARK: - Anfänge

    private static func firstSessionEvent(_ sessions: [ClimbSession]) -> PendingUnlock? {
        guard let s = sessions.min(by: { $0.date < $1.date }) else { return nil }
        return PendingUnlock(definitionID: "first_session", tier: nil, date: s.date, contextValue: nil, sessionID: s.id)
    }

    private static func firstTopEvent(_ sessions: [ClimbSession]) -> PendingUnlock? {
        guard let a = sessions.flatMap(\.ascents).filter({ $0.result == .top }).min(by: { $0.date < $1.date })
        else { return nil }
        return PendingUnlock(definitionID: "first_top", tier: nil, date: a.date, contextValue: nil, sessionID: a.session?.id)
    }

    private static func firstReflectionEvent(_ sessions: [ClimbSession]) -> PendingUnlock? {
        guard let s = sessions.filter(\.reflectionCompleted).min(by: { $0.date < $1.date }) else { return nil }
        return PendingUnlock(definitionID: "first_reflection", tier: nil, date: s.date, contextValue: nil, sessionID: s.id)
    }

    private static func firstOutdoorEvent(_ sessions: [ClimbSession]) -> PendingUnlock? {
        guard let s = sessions.filter(\.outdoor).min(by: { $0.date < $1.date }) else { return nil }
        return PendingUnlock(definitionID: "first_outdoor", tier: nil, date: s.date, contextValue: nil, sessionID: s.id)
    }

    /// Kletter-Disziplinen (Training zählt nicht) im Sinne von `discipline_trio`.
    private static let climbingDisciplines: Set<SessionType> = [.boulder, .lead, .topRope, .autoBelay]

    private static func disciplineTrioEvent(_ sessions: [ClimbSession]) -> PendingUnlock? {
        let sorted = sessions.filter { climbingDisciplines.contains($0.sessionType) }.sorted { $0.date < $1.date }
        var seen = Set<SessionType>()
        for s in sorted {
            seen.insert(s.sessionType)
            if seen.count >= 3 {
                return PendingUnlock(definitionID: "discipline_trio", tier: nil, date: s.date, contextValue: nil, sessionID: s.id)
            }
        }
        return nil
    }

    // MARK: - Konsistenz

    private static func climbingWeekStarts(_ sessions: [ClimbSession], calendar: Calendar) -> [Date] {
        var cal = calendar
        cal.firstWeekday = 2
        let starts = Set(sessions.filter(\.isClimbing).compactMap { cal.dateInterval(of: .weekOfYear, for: $0.date)?.start })
        return starts.sorted()
    }

    private static func weekStreakEvents(_ sessions: [ClimbSession], calendar: Calendar) -> [PendingUnlock] {
        guard case .tiered(let tiers) = AchievementDefinition.definition(id: "week_streak")!.kind else { return [] }
        var cal = calendar
        cal.firstWeekday = 2
        let weekStarts = climbingWeekStarts(sessions, calendar: cal)
        guard !weekStarts.isEmpty else { return [] }

        var out: [PendingUnlock] = []
        var runLength = 0
        var prevWeek: Date?
        var triggered = Set<Int>()
        for week in weekStarts {
            if let prevWeek, let next = cal.date(byAdding: .weekOfYear, value: 1, to: prevWeek),
               cal.isDate(next, inSameDayAs: week) {
                runLength += 1
            } else {
                runLength = 1
            }
            prevWeek = week
            for (i, tier) in tiers.enumerated() where runLength == tier.threshold && !triggered.contains(i) {
                triggered.insert(i)
                let weekEnd = cal.date(byAdding: .weekOfYear, value: 1, to: week) ?? week
                let trigger = sessions.filter { $0.isClimbing && $0.date >= week && $0.date < weekEnd }
                    .min { $0.date < $1.date }
                out.append(PendingUnlock(definitionID: "week_streak", tier: i, date: trigger?.date ?? week,
                                         contextValue: nil, sessionID: trigger?.id))
            }
        }
        return out
    }

    private static func sessionsTotalEvents(_ sessions: [ClimbSession]) -> [PendingUnlock] {
        guard case .tiered(let tiers) = AchievementDefinition.definition(id: "sessions_total")!.kind else { return [] }
        return cumulativeCountCrossings(sessions, tiers: tiers, definitionID: "sessions_total",
                                        date: \.date, sessionID: \.id)
    }

    private static func climbDaysInYear(_ sessions: [ClimbSession], year: Int, calendar: Calendar) -> Int {
        Set(sessions.filter { $0.isClimbing && calendar.component(.year, from: $0.date) == year }
            .map { calendar.startOfDay(for: $0.date) }).count
    }

    private static func climbDaysYearEvents(_ sessions: [ClimbSession], calendar: Calendar) -> [PendingUnlock] {
        let threshold = 50
        let years = Set(sessions.filter(\.isClimbing).map { calendar.component(.year, from: $0.date) })
        var out: [PendingUnlock] = []
        for year in years {
            let daySessions = sessions.filter { $0.isClimbing && calendar.component(.year, from: $0.date) == year }
            var earliestPerDay: [Date: ClimbSession] = [:]
            for s in daySessions {
                let day = calendar.startOfDay(for: s.date)
                if let existing = earliestPerDay[day] {
                    if s.date < existing.date { earliestPerDay[day] = s }
                } else {
                    earliestPerDay[day] = s
                }
            }
            let sortedDays = earliestPerDay.keys.sorted()
            guard sortedDays.count >= threshold else { continue }
            let triggerDay = sortedDays[threshold - 1]
            let trigger = earliestPerDay[triggerDay]
            out.append(PendingUnlock(definitionID: "climb_days_year", tier: nil, date: trigger?.date ?? triggerDay,
                                     contextValue: String(year), sessionID: trigger?.id))
        }
        return out
    }

    private static func comebackEvent(_ sessions: [ClimbSession], calendar: Calendar) -> PendingUnlock? {
        let sorted = sessions.filter(\.isClimbing).sorted { $0.date < $1.date }
        guard sorted.count >= 2 else { return nil }
        for i in 1..<sorted.count {
            let gap = calendar.dateComponents([.day], from: sorted[i - 1].date, to: sorted[i].date).day ?? 0
            if gap >= 30 {
                return PendingUnlock(definitionID: "comeback", tier: nil, date: sorted[i].date,
                                     contextValue: nil, sessionID: sorted[i].id)
            }
        }
        return nil
    }

    // MARK: - Schwierigkeit

    private static func gradedTops(_ sessions: [ClimbSession], boulder: Bool) -> [Ascent] {
        sessions.flatMap(\.ascents)
            .filter { $0.result == .top && $0.isGraded && $0.gradeSystem.isBoulder == boulder }
            .sorted { $0.date < $1.date }
    }

    private static func pbEvents(_ sessions: [ClimbSession], definitionID: String, boulder: Bool) -> [PendingUnlock] {
        var out: [PendingUnlock] = []
        var runningMax = Int.min
        for a in gradedTops(sessions, boulder: boulder) {
            if a.canonicalOrder > runningMax {
                runningMax = a.canonicalOrder
                let grade = GradeConverter.display(grade: a.gradeRaw, storedIn: a.gradeSystem)
                out.append(PendingUnlock(definitionID: definitionID, tier: nil, date: a.date,
                                         contextValue: grade, sessionID: a.session?.id))
            }
        }
        return out
    }

    private static func gradeMilestoneEvents(_ sessions: [ClimbSession], definitionID: String, boulder: Bool) -> [PendingUnlock] {
        guard case .tiered(let tiers) = AchievementDefinition.definition(id: definitionID)!.kind else { return [] }
        var out: [PendingUnlock] = []
        var triggered = Set<Int>()
        for a in gradedTops(sessions, boulder: boulder) {
            for (i, tier) in tiers.enumerated() where !triggered.contains(i) && a.canonicalOrder >= tier.threshold {
                triggered.insert(i)
                out.append(PendingUnlock(definitionID: definitionID, tier: i, date: a.date,
                                         contextValue: nil, sessionID: a.session?.id))
            }
        }
        return out
    }

    // MARK: - Stil

    private static func flashOnsightTotalEvents(_ sessions: [ClimbSession], definitionID: String,
                                                 style: AscentStyle) -> [PendingUnlock] {
        guard case .tiered(let tiers) = AchievementDefinition.definition(id: definitionID)!.kind else { return [] }
        let items = sessions.flatMap(\.ascents).filter { $0.result == .top && $0.style == style }
        return cumulativeCountCrossings(items, tiers: tiers, definitionID: definitionID,
                                        date: \.date, sessionID: { $0.session?.id })
    }

    private static func flashDayEvents(_ sessions: [ClimbSession]) -> [PendingUnlock] {
        sessions.compactMap { s in
            let count = s.ascents.filter { $0.result == .top && $0.style == .flash }.count
            guard count >= 3 else { return nil }
            return PendingUnlock(definitionID: "flash_day", tier: nil, date: s.date,
                                 contextValue: String(count), sessionID: s.id)
        }
    }

    private static func angleAllrounderEvent(_ sessions: [ClimbSession]) -> PendingUnlock? {
        let tops = sessions.flatMap(\.ascents)
            .filter { $0.result == .top && $0.wallAngle != nil }
            .sorted { $0.date < $1.date }
        var seen = Set<WallAngle>()
        for a in tops {
            if let angle = a.wallAngle { seen.insert(angle) }
            if seen.count >= WallAngle.allCases.count {
                return PendingUnlock(definitionID: "angle_allrounder", tier: nil, date: a.date,
                                     contextValue: nil, sessionID: a.session?.id)
            }
        }
        return nil
    }

    // MARK: - Ausdauer

    private static func topsTotalEvents(_ sessions: [ClimbSession]) -> [PendingUnlock] {
        guard case .tiered(let tiers) = AchievementDefinition.definition(id: "tops_total")!.kind else { return [] }
        let tops = sessions.flatMap(\.ascents).filter { $0.result == .top }
        return cumulativeCountCrossings(tops, tiers: tiers, definitionID: "tops_total",
                                        date: \.date, sessionID: { $0.session?.id })
    }

    private static func hoursTotalEvents(_ sessions: [ClimbSession]) -> [PendingUnlock] {
        guard case .tiered(let tiers) = AchievementDefinition.definition(id: "hours_total")!.kind else { return [] }
        let climbing = sessions.filter(\.isClimbing).sorted { $0.date < $1.date }
        return cumulativeSumCrossings(climbing, tiers: tiers, definitionID: "hours_total",
                                      value: { $0.activeSeconds / 3600 }, date: \.date, sessionID: \.id)
    }

    private static func altitudeTotalEvents(_ sessions: [ClimbSession]) -> [PendingUnlock] {
        guard case .tiered(let tiers) = AchievementDefinition.definition(id: "altitude_total")!.kind else { return [] }
        let ascents = sessions.flatMap(\.ascents).sorted { $0.date < $1.date }
        return cumulativeSumCrossings(ascents, tiers: tiers, definitionID: "altitude_total",
                                      value: \.altitudeGain, date: \.date, sessionID: { $0.session?.id })
    }

    private static func bigDayEvents(_ sessions: [ClimbSession]) -> [PendingUnlock] {
        sessions.compactMap { s in
            let count = s.ascents.filter { $0.result == .top }.count
            guard count >= 20 else { return nil }
            return PendingUnlock(definitionID: "big_day", tier: nil, date: s.date,
                                 contextValue: String(count), sessionID: s.id)
        }
    }

    // MARK: - Projekte

    private struct SentProject {
        let project: Project
        let date: Date
        let sessionID: UUID?
    }

    private static func sentProjectsChronological(_ projects: [Project]) -> [SentProject] {
        projects.compactMap { p -> SentProject? in
            guard p.isSent,
                  let ascent = p.ascents.filter({ $0.result == .top }).min(by: { $0.date < $1.date })
            else { return nil }
            return SentProject(project: p, date: ascent.date, sessionID: ascent.session?.id)
        }.sorted { $0.date < $1.date }
    }

    private static func projectsTotalEvents(_ sent: [SentProject]) -> [PendingUnlock] {
        guard case .tiered(let tiers) = AchievementDefinition.definition(id: "projects_total")!.kind else { return [] }
        return cumulativeCountCrossings(sent, tiers: tiers, definitionID: "projects_total",
                                        date: \.date, sessionID: \.sessionID)
    }

    private static func projectPersistentEvents(_ sent: [SentProject]) -> [PendingUnlock] {
        sent.compactMap { s in
            // S32/FB-8: Ascent-Datensätze zählen (jeder Datensatz = ein realer Versuch),
            // nie das unzuverlässige `attempts`-Feld.
            guard s.project.ascents.count >= 10 else { return nil }
            return PendingUnlock(definitionID: "project_persistent", tier: nil, date: s.date,
                                 contextValue: s.project.name, sessionID: s.sessionID)
        }
    }

    private static func projectLonggameEvent(_ sent: [SentProject]) -> PendingUnlock? {
        guard let s = sent.first(where: { $0.project.distinctDays >= 3 }) else { return nil }
        return PendingUnlock(definitionID: "project_longgame", tier: nil, date: s.date,
                             contextValue: nil, sessionID: s.sessionID)
    }

    // MARK: - Besondere Momente

    private static func dawnPatrolEvent(_ sessions: [ClimbSession], calendar: Calendar) -> PendingUnlock? {
        guard let s = sessions.filter(\.isClimbing).sorted(by: { $0.date < $1.date })
            .first(where: { calendar.component(.hour, from: $0.date) < 7 })
        else { return nil }
        return PendingUnlock(definitionID: "dawn_patrol", tier: nil, date: s.date, contextValue: nil, sessionID: s.id)
    }

    private static func gradeLeapEvent(_ sessions: [ClimbSession]) -> PendingUnlock? {
        func leap(boulder: Bool) -> PendingUnlock? {
            var runningMax = Int.min
            for a in gradedTops(sessions, boulder: boulder) {
                if runningMax != Int.min, a.canonicalOrder - runningMax >= 2 {
                    let grade = GradeConverter.display(grade: a.gradeRaw, storedIn: a.gradeSystem)
                    return PendingUnlock(definitionID: "grade_leap", tier: nil, date: a.date,
                                         contextValue: grade, sessionID: a.session?.id)
                }
                if a.canonicalOrder > runningMax { runningMax = a.canonicalOrder }
            }
            return nil
        }
        return [leap(boulder: true), leap(boulder: false)].compactMap { $0 }.min { $0.date < $1.date }
    }

    private static func newYearClimbEvent(_ sessions: [ClimbSession], calendar: Calendar) -> PendingUnlock? {
        guard let s = sessions.filter(\.isClimbing).sorted(by: { $0.date < $1.date }).first(where: {
            let c = calendar.dateComponents([.month, .day], from: $0.date)
            return c.month == 1 && c.day == 1
        }) else { return nil }
        return PendingUnlock(definitionID: "new_year_climb", tier: nil, date: s.date, contextValue: nil, sessionID: s.id)
    }

    // MARK: - Generische Zähl-Helfer

    private static func cumulativeCountCrossings<T>(_ items: [T], tiers: [AchievementTier], definitionID: String,
                                                     date: (T) -> Date, sessionID: (T) -> UUID?) -> [PendingUnlock] {
        let sorted = items.sorted { date($0) < date($1) }
        var out: [PendingUnlock] = []
        for (i, tier) in tiers.enumerated() {
            guard sorted.count >= tier.threshold, tier.threshold > 0 else { continue }
            let item = sorted[tier.threshold - 1]
            out.append(PendingUnlock(definitionID: definitionID, tier: i, date: date(item),
                                     contextValue: nil, sessionID: sessionID(item)))
        }
        return out
    }

    private static func cumulativeSumCrossings<T>(_ items: [T], tiers: [AchievementTier], definitionID: String,
                                                   value: (T) -> Double, date: (T) -> Date,
                                                   sessionID: (T) -> UUID?) -> [PendingUnlock] {
        var out: [PendingUnlock] = []
        var running = 0.0
        var triggered = Set<Int>()
        for item in items {
            running += value(item)
            for (i, tier) in tiers.enumerated() where !triggered.contains(i) && running >= Double(tier.threshold) {
                triggered.insert(i)
                out.append(PendingUnlock(definitionID: definitionID, tier: i, date: date(item),
                                         contextValue: nil, sessionID: sessionID(item)))
            }
        }
        return out
    }

    // MARK: - Fortschritt (In Reichweite / Detail-Sheet)

    private static func currentTieredValue(_ id: String, sessions: [ClimbSession], projects: [Project],
                                           calendar: Calendar) -> Int? {
        switch id {
        case "week_streak":
            var cal = calendar
            cal.firstWeekday = 2
            let weekStarts = climbingWeekStarts(sessions, calendar: cal)
            guard !weekStarts.isEmpty else { return 0 }
            var run = 1
            for i in stride(from: weekStarts.count - 1, to: 0, by: -1) {
                if let prev = cal.date(byAdding: .weekOfYear, value: -1, to: weekStarts[i]),
                   cal.isDate(prev, inSameDayAs: weekStarts[i - 1]) {
                    run += 1
                } else { break }
            }
            return run
        case "sessions_total":
            return sessions.count
        case "tops_total":
            return sessions.flatMap(\.ascents).filter { $0.result == .top }.count
        case "hours_total":
            let seconds = sessions.filter(\.isClimbing).reduce(0.0) { $0 + $1.activeSeconds }
            return Int(seconds / 3600)
        case "altitude_total":
            return Int(sessions.flatMap(\.ascents).reduce(0.0) { $0 + $1.altitudeGain })
        case "flash_total":
            return sessions.flatMap(\.ascents).filter { $0.result == .top && $0.style == .flash }.count
        case "onsight_total":
            return sessions.flatMap(\.ascents).filter { $0.result == .top && $0.style == .onsight }.count
        case "grade_boulder":
            return gradedTops(sessions, boulder: true).map(\.canonicalOrder).max()
        case "grade_route":
            return gradedTops(sessions, boulder: false).map(\.canonicalOrder).max()
        case "projects_total":
            return sentProjectsChronological(projects).count
        default:
            return nil
        }
    }

    /// (current, target) für `once`-Definitionen mit sinnvoller Teilstrecke.
    private static func onceProgressValue(_ id: String, sessions: [ClimbSession],
                                          projects: [Project]) -> (Int, Int)? {
        switch id {
        case "discipline_trio":
            let seen = Set(sessions.filter { climbingDisciplines.contains($0.sessionType) }.map(\.sessionType))
            return (min(seen.count, 3), 3)
        case "angle_allrounder":
            let seen = Set(sessions.flatMap(\.ascents).filter { $0.result == .top }.compactMap(\.wallAngle))
            return (seen.count, WallAngle.allCases.count)
        default:
            return nil
        }
    }

    private static func remainingText(_ id: String, current: Int, target: Int) -> String {
        let remaining = max(0, target - current)
        switch id {
        case "week_streak":       return "Noch \(remaining) Woche\(remaining == 1 ? "" : "n") bis \(target)"
        case "sessions_total":    return "Noch \(remaining) Session\(remaining == 1 ? "" : "s") bis \(target)"
        case "tops_total":        return "Noch \(remaining) Top\(remaining == 1 ? "" : "s") bis \(target)"
        case "hours_total":       return "Noch \(remaining) Stunde\(remaining == 1 ? "" : "n") bis \(target)"
        case "altitude_total":    return "Noch \(remaining) m bis \(target) m"
        case "flash_total":       return "Noch \(remaining) Flash\(remaining == 1 ? "" : "es") bis \(target)"
        case "onsight_total":     return "Noch \(remaining) Onsight\(remaining == 1 ? "" : "s") bis \(target)"
        case "grade_boulder", "grade_route":
            return "Noch \(remaining) Stufe\(remaining == 1 ? "" : "n") bis zur nächsten Marke"
        case "projects_total":    return "Noch \(remaining) Projekt\(remaining == 1 ? "" : "e") bis \(target)"
        case "discipline_trio":   return "Noch \(remaining) Disziplin\(remaining == 1 ? "" : "en")"
        case "angle_allrounder":  return "Noch \(remaining) Wandwinkel"
        case "climb_days_year":   return "Noch \(remaining) Klettertage bis \(target)"
        default:                 return "Noch \(remaining) bis \(target)"
        }
    }
}
