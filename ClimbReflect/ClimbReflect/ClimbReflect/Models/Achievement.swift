import Foundation
import SwiftUI

// MARK: - Erfolg (Achievement)

struct Achievement: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let isUnlocked: Bool
    let progress: Double      // 0…1 für gesperrte Erfolge
}

// MARK: - Wochen-Punkt für die Chart

struct WeeklyPoint: Identifiable {
    let id = UUID()
    let weekStart: Date
    let minutes: Int
    let sessions: Int

    var label: String {
        let cal = Calendar.current
        let kw = cal.component(.weekOfYear, from: weekStart)
        return "KW \(kw)"
    }
}

// MARK: - RPE-Datenpunkt

struct RPEPoint: Identifiable {
    let id = UUID()
    let date: Date
    let rpe: Int
    let sessionType: SessionType
}

// MARK: - Sessiontyp-Verteilung

struct TypeCount: Identifiable {
    let id: String
    let sessionType: SessionType
    let count: Int
    let share: Double
}

// MARK: - Trainings-Schwäche

struct TrainingWeakness {
    let topLimiter: Limiter?
    let monthlyTrainingCount: Int
}

// MARK: - Engine: leitet Statistik, Wochenverlauf und Erfolge aus den Sessions ab

enum StatsEngine {

    private static func climbing(_ sessions: [ClimbSession]) -> [ClimbSession] {
        sessions.filter { $0.isClimbing }
    }

    /// Klettermin. pro Woche der letzten `weeks` Wochen (inkl. leerer Wochen).
    static func weeklyMinutes(_ sessions: [ClimbSession], weeks: Int = 8,
                              calendar: Calendar = .current) -> [WeeklyPoint] {
        var cal = calendar
        cal.firstWeekday = 2 // Montag
        let now = Date()
        guard let thisWeekStart = cal.dateInterval(of: .weekOfYear, for: now)?.start
        else { return [] }

        var points: [WeeklyPoint] = []
        for offset in stride(from: weeks - 1, through: 0, by: -1) {
            guard let start = cal.date(byAdding: .weekOfYear, value: -offset, to: thisWeekStart),
                  let end = cal.date(byAdding: .weekOfYear, value: 1, to: start)
            else { continue }
            let inWeek = sessions.filter { $0.date >= start && $0.date < end }
            let minutes = inWeek.reduce(0) { $0 + $1.durationMinutes }
            points.append(WeeklyPoint(weekStart: start, minutes: minutes, sessions: inWeek.count))
        }
        return points
    }

    /// Aufeinanderfolgende Wochen (ab dieser Woche rückwärts) mit ≥1 Session.
    static func weekStreak(_ sessions: [ClimbSession], calendar: Calendar = .current) -> Int {
        let weeks = weeklyMinutes(sessions, weeks: 26, calendar: calendar)
        var streak = 0
        for point in weeks.reversed() {
            if point.sessions > 0 { streak += 1 } else { break }
        }
        return streak
    }

    /// Wie weekStreak, aber nur Klettersessions (Training ausgeschlossen).
    static func climbWeekStreak(_ sessions: [ClimbSession], calendar: Calendar = .current) -> Int {
        weekStreak(climbing(sessions), calendar: calendar)
    }

    /// RPE-Verlauf der letzten `limit` Sessions mit gesetztem RPE, chronologisch.
    static func rpeHistory(_ sessions: [ClimbSession], limit: Int = 20) -> [RPEPoint] {
        sessions
            .filter { $0.perceivedEffort != nil }
            .sorted { $0.date < $1.date }
            .suffix(limit)
            .compactMap { s in
                guard let rpe = s.perceivedEffort else { return nil }
                return RPEPoint(date: s.date, rpe: rpe, sessionType: s.sessionType)
            }
    }

    /// Anzahl Sessions pro Typ, absteigend sortiert.
    static func sessionTypeDistribution(_ sessions: [ClimbSession]) -> [TypeCount] {
        var counts: [SessionType: Int] = [:]
        for s in sessions { counts[s.sessionType, default: 0] += 1 }
        let total = max(1, Double(sessions.count))
        return counts
            .map { TypeCount(id: $0.key.rawValue, sessionType: $0.key, count: $0.value, share: Double($0.value) / total) }
            .sorted { $0.count > $1.count }
    }

    // MARK: Grad-Pyramide (P3.3)

    struct PyramidEntry: Identifiable {
        let id: String
        let grade: String
        let gradeSystem: GradeSystem
        let tops: Int
        let attempts: Int
        let sortOrder: Int
    }

    // MARK: Send-Rate & Flash-Quote (P3.4)

    struct SendStats {
        let totalAscents: Int
        let tops: Int
        let flashes: Int
        let sendRate: Double     // tops / totalAscents
        let flashRate: Double    // flashes / tops
    }

    static func sendStats(_ sessions: [ClimbSession]) -> SendStats {
        let all = climbing(sessions).flatMap(\.ascents)
        let tops = all.filter { $0.result == .top }
        let flashes = tops.filter { $0.style == .flash }
        let total = max(1, all.count)
        return SendStats(
            totalAscents: all.count,
            tops: tops.count,
            flashes: flashes.count,
            sendRate: Double(tops.count) / Double(total),
            flashRate: tops.isEmpty ? 0 : Double(flashes.count) / Double(tops.count)
        )
    }

    // MARK: Grad-Pyramide (P3.3)

    static func gradePyramid(_ sessions: [ClimbSession],
                             system: GradeSystem) -> [PyramidEntry] {
        let allAscents = climbing(sessions).flatMap(\.ascents).filter {
            $0.gradeSystem == system
        }
        guard !allAscents.isEmpty else { return [] }

        var groups: [String: (tops: Int, attempts: Int)] = [:]
        for a in allAscents {
            let key = a.gradeRaw
            var entry = groups[key, default: (0, 0)]
            if a.result == .top { entry.tops += 1 } else { entry.attempts += 1 }
            groups[key] = entry
        }
        return groups.compactMap { grade, counts in
            guard counts.tops > 0 || counts.attempts > 0 else { return nil }
            return PyramidEntry(
                id: grade,
                grade: grade,
                gradeSystem: system,
                tops: counts.tops,
                attempts: counts.attempts,
                sortOrder: system.sortOrder(of: grade)
            )
        }
        .sorted { $0.sortOrder > $1.sortOrder }
    }

    static func totalMinutes(_ sessions: [ClimbSession]) -> Int {
        sessions.reduce(0) { $0 + $1.durationMinutes }
    }

    /// Häufigster Limiter aus Klettersessions + Trainings dagegen diesen Monat.
    static func trainingWeakness(_ sessions: [ClimbSession]) -> TrainingWeakness {
        var limiterCounts: [Limiter: Int] = [:]
        for s in climbing(sessions) {
            for l in s.limiters { limiterCounts[l, default: 0] += 1 }
        }
        guard let topLimiter = limiterCounts.max(by: { $0.value < $1.value })?.key else {
            return TrainingWeakness(topLimiter: nil, monthlyTrainingCount: 0)
        }
        let monthAgo = Calendar.current.date(byAdding: .month, value: -1, to: .now) ?? .now
        let count = sessions
            .filter { !$0.isClimbing && $0.date >= monthAgo && $0.limiters.contains(topLimiter) }
            .count
        return TrainingWeakness(topLimiter: topLimiter, monthlyTrainingCount: count)
    }

    static func sessionsThisWeek(_ sessions: [ClimbSession]) -> Int {
        weeklyMinutes(sessions, weeks: 1).first?.sessions ?? 0
    }

    // MARK: Form-/Plateau-Signal (P3.12)

    enum FormSignal: Equatable {
        case deloadSuggested   // RPE hoch + Send-Rate sinkt
        case techniqueSuggested // Grad flach + RPE hoch über Zeit
        case formGood           // alles im grünen Bereich
    }

    static func formSignal(_ sessions: [ClimbSession]) -> FormSignal {
        let climbSessions = climbing(sessions)
        let recent = climbSessions.sorted { $0.date > $1.date }.prefix(6)
        guard recent.count >= 4 else { return .formGood }

        let avgRPE = recent.compactMap(\.perceivedEffort).map(Double.init)
        guard !avgRPE.isEmpty else { return .formGood }
        let rpe = avgRPE.reduce(0, +) / Double(avgRPE.count)

        let recentAscents = recent.flatMap(\.ascents)
        guard recentAscents.count >= 4 else { return .formGood }
        let sendRate = Double(recentAscents.filter { $0.result == .top }.count) / Double(recentAscents.count)

        if rpe >= 8.0 && sendRate < 0.35 { return .deloadSuggested }

        let allSorted = climbSessions.sorted { $0.date < $1.date }
        let half = allSorted.count / 2
        if half >= 2 {
            let older = allSorted.prefix(half).flatMap(\.ascents)
            let newer = allSorted.suffix(half).flatMap(\.ascents)
            let olderMax = older.filter { $0.result == .top }.map(\.sortOrder).max() ?? 0
            let newerMax = newer.filter { $0.result == .top }.map(\.sortOrder).max() ?? 0
            if newerMax <= olderMax && rpe >= 7.5 { return .techniqueSuggested }
        }
        return .formGood
    }

    // MARK: Antistyle-Auswertung (P3.7)

    struct StyleSendRate: Identifiable {
        let id: String
        let label: String
        let category: String   // "Wandwinkel" | "Grifftyp" | "Kletterart"
        let sendRate: Double   // 0.0–1.0
        let totalAscents: Int
    }

    static func antistyleRates(_ sessions: [ClimbSession]) -> [StyleSendRate] {
        let all = climbing(sessions).flatMap(\.ascents)
        guard !all.isEmpty else { return [] }

        var result: [StyleSendRate] = []

        for angle in WallAngle.allCases {
            let group = all.filter { $0.wallAngle == angle }
            guard !group.isEmpty else { continue }
            let tops = group.filter { $0.result == .top }.count
            result.append(StyleSendRate(
                id: "angle_\(angle.rawValue)",
                label: angle.label,
                category: "Wandwinkel",
                sendRate: Double(tops) / Double(group.count),
                totalAscents: group.count
            ))
        }
        for hold in HoldType.allCases {
            let group = all.filter { $0.holdType == hold }
            guard !group.isEmpty else { continue }
            let tops = group.filter { $0.result == .top }.count
            result.append(StyleSendRate(
                id: "hold_\(hold.rawValue)",
                label: hold.label,
                category: "Grifftyp",
                sendRate: Double(tops) / Double(group.count),
                totalAscents: group.count
            ))
        }
        for style in ClimbStyle.allCases {
            let group = all.filter { $0.climbStyle == style }
            guard !group.isEmpty else { continue }
            let tops = group.filter { $0.result == .top }.count
            result.append(StyleSendRate(
                id: "style_\(style.rawValue)",
                label: style.label,
                category: "Kletterart",
                sendRate: Double(tops) / Double(group.count),
                totalAscents: group.count
            ))
        }
        return result.sorted { $0.sendRate < $1.sendRate }  // Schwächen zuerst
    }

    // MARK: Wochen-Recap (P3.10)

    struct WeekRecap {
        let weekStart: Date
        let weekEnd: Date
        let tops: Int
        let sessions: Int
        let minutes: Int
        let avgRPE: Double?
        let highestGrade: String?
        let highestGradeSystem: GradeSystem?
        let newPB: Bool        // neuer Höchstgrad im Vergleich zu Vorwochen
    }

    static func currentWeekRecap(_ sessions: [ClimbSession]) -> WeekRecap {
        var cal = Calendar.current
        cal.firstWeekday = 2
        let now = Date()
        guard let interval = cal.dateInterval(of: .weekOfYear, for: now) else {
            return WeekRecap(weekStart: now, weekEnd: now, tops: 0, sessions: 0,
                             minutes: 0, avgRPE: nil, highestGrade: nil,
                             highestGradeSystem: nil, newPB: false)
        }
        let thisWeekAll = sessions.filter { $0.date >= interval.start && $0.date < interval.end }
        let thisWeek = thisWeekAll.filter { $0.isClimbing }
        let prevSessions = climbing(sessions).filter { $0.date < interval.start }

        let allAscents = thisWeek.flatMap(\.ascents)
        let tops = allAscents.filter { $0.result == .top }
        let topsSorted = tops.sorted { $0.sortOrder > $1.sortOrder }
        let highest = topsSorted.first

        let prevTops = prevSessions.flatMap(\.ascents).filter { $0.result == .top }
        let prevMaxOrder = prevTops.map(\.sortOrder).max() ?? -1
        let newPB = (highest?.sortOrder ?? -1) > prevMaxOrder

        let rpes = thisWeekAll.compactMap(\.perceivedEffort).map(Double.init)
        let avgRPE = rpes.isEmpty ? nil : rpes.reduce(0, +) / Double(rpes.count)

        return WeekRecap(
            weekStart: interval.start,
            weekEnd: interval.end,
            tops: tops.count,
            sessions: thisWeekAll.count,
            minutes: thisWeekAll.reduce(0) { $0 + $1.durationMinutes },
            avgRPE: avgRPE,
            highestGrade: highest?.gradeRaw,
            highestGradeSystem: highest?.gradeSystem,
            newPB: newPB
        )
    }

    // MARK: Adaptive Kletter-Erfolge (P3.9)

    struct ClimbAchievement: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let symbol: String
        let isUnlocked: Bool
        let color: Color
        let explanation: String
    }

    static func climbAchievements(for sessions: [ClimbSession]) -> [ClimbAchievement] {
        let climbSessions = climbing(sessions)
        let allAscents = climbSessions.flatMap(\.ascents)
        let tops = allAscents.filter { $0.result == .top }
        let flashes = tops.filter { $0.style == .flash }

        // Neuer Höchstgrad
        let maxGrade = tops.max { $0.sortOrder < $1.sortOrder }

        // 3 Flashes in einer Session
        let bestFlashSession = climbSessions
            .map { ($0, $0.ascents.filter { $0.style == .flash }.count) }
            .max { $0.1 < $1.1 }

        // Projekt gesendet (> 5 Versuche)
        let projectSent = tops.first { a in
            guard let name = a.projectName else { return false }
            let totalAttempts = allAscents
                .filter { $0.projectName == name }
                .reduce(0) { $0 + $1.attempts }
            return totalAttempts >= 5
        }

        // Comeback (Session nach ≥14 Tagen Pause)
        let sortedDates = climbSessions.map(\.date).sorted()
        let comeback = zip(sortedDates, sortedDates.dropFirst())
            .contains { Calendar.current.dateComponents([.day], from: $0.0, to: $0.1).day ?? 0 >= 14 }

        // Flash-Quote ≥ 30%
        let goodFlashRate = tops.count >= 5 && Double(flashes.count) / Double(tops.count) >= 0.30

        return [
            ClimbAchievement(
                id: "new_pb",
                title: "Neuer Höchstgrad",
                subtitle: maxGrade.map { "Gesendet: \($0.gradeRaw)" } ?? "Noch kein Top",
                symbol: "trophy.fill",
                isUnlocked: maxGrade != nil,
                color: Theme.gold,
                explanation: "Du hast mindestens einen Boulder oder eine Route erfolgreich gesendet. Der aktuell beste Rotpunkt erscheint auf dem Dashboard."
            ),
            ClimbAchievement(
                id: "triple_flash",
                title: "Flash-Session",
                subtitle: (bestFlashSession?.1 ?? 0) >= 3
                    ? "3 Flashes in einer Session!"
                    : "\(bestFlashSession?.1 ?? 0)/3 Flashes",
                symbol: "bolt.circle.fill",
                isUnlocked: (bestFlashSession?.1 ?? 0) >= 3,
                color: Theme.accent,
                explanation: "Du hast in einer einzigen Session mindestens 3 Boulder oder Routen geflasht — also im ersten Versuch ohne Vorwissen gesendet. Ein Flash zeigt starke Lese- und Bewegungskompetenz."
            ),
            ClimbAchievement(
                id: "project_done",
                title: "Hartnäckig",
                subtitle: projectSent != nil
                    ? "Projekt \(projectSent!.projectName!) gesendet!"
                    : "Projekt mit 5+ Versuchen senden",
                symbol: "target",
                isUnlocked: projectSent != nil,
                color: Theme.accent,
                explanation: "Du hast ein Projekt mit mindestens 5 Versuchen schließlich gesendet. Hartnäckigkeit zahlt sich aus — dieser Erfolg würdigt Ausdauer über mehrere Sessions hinweg."
            ),
            ClimbAchievement(
                id: "comeback",
                title: "Comeback",
                subtitle: comeback ? "Nach Pause zurück!" : "Nach 14 Tagen Pause klettern",
                symbol: "arrow.up.heart.fill",
                isUnlocked: comeback,
                color: Theme.danger,
                explanation: "Nach einer Pause von mindestens 14 Tagen bist du wieder an die Wand gegangen. Rückkehren nach einer Pause erfordert Überwindung — gut gemacht!"
            ),
            ClimbAchievement(
                id: "flash_rate",
                title: "Flash-Meister",
                subtitle: goodFlashRate
                    ? "≥ 30% Flash-Quote!"
                    : "Erziele ≥30% Flash-Quote (mind. 5 Tops)",
                symbol: "star.circle.fill",
                isUnlocked: goodFlashRate,
                color: Theme.gold,
                explanation: "Von mindestens 5 Tops hast du ≥30% im ersten Versuch (Flash) gesendet. Eine hohe Flash-Quote zeigt, dass du Routen gut lesen und direkt umsetzen kannst."
            ),
        ]
    }

    // MARK: - Session-Insights (SI-1)

    struct SessionInsights {
        let totalSeconds: Double
        let activeSeconds: Double
        var pauseSeconds: Double { max(0, totalSeconds - activeSeconds) }
        var activeShare: Double { totalSeconds > 0 ? activeSeconds / totalSeconds : 0 }
        let hasAttemptTimes: Bool
        let avgAttemptSeconds: Double?
        let longestAttemptSeconds: Double?
        let sendsPerHour: Double?
        let load: Int?
        let successRate: Double?
        let attemptsPerSend: Double?
        let hardestTopGrade: String?
    }

    static func insights(for session: ClimbSession) -> SessionInsights {
        let ascents = session.ascents
        let timed = ascents.compactMap(\.durationSeconds).filter { $0 > 0 }
        let activeRaw = timed.reduce(0, +)
        let active = min(activeRaw, session.durationSeconds)
        let hasAttemptTimes = !timed.isEmpty

        let tops = ascents.filter { $0.result == .top }
        let total = session.durationSeconds
        let sendsPerHour: Double? = total > 0 && !tops.isEmpty
            ? Double(tops.count) / (total / 3600)
            : nil

        let load = session.perceivedEffort.map { Int(Double($0) * total / 60) }

        let successRate: Double? = ascents.isEmpty ? nil
            : Double(tops.count) / Double(ascents.count)

        let attemptsPerSend: Double? = tops.isEmpty ? nil
            : Double(tops.reduce(0) { $0 + $1.attempts }) / Double(tops.count)

        let hardestTopGrade = tops.max(by: { $0.sortOrder < $1.sortOrder })?.gradeRaw

        return SessionInsights(
            totalSeconds: total,
            activeSeconds: active,
            hasAttemptTimes: hasAttemptTimes,
            avgAttemptSeconds: hasAttemptTimes ? activeRaw / Double(timed.count) : nil,
            longestAttemptSeconds: timed.max(),
            sendsPerHour: sendsPerHour,
            load: load,
            successRate: successRate,
            attemptsPerSend: attemptsPerSend,
            hardestTopGrade: hardestTopGrade
        )
    }

    // MARK: - A1: Effizienz-Trend

    struct EfficiencyPoint: Identifiable {
        let id = UUID()
        let monthStart: Date
        let avgAttemptsToTop: Double?
        let flashRate: Double?
    }

    static func efficiencyTrend(_ sessions: [ClimbSession], months: Int = 6,
                                calendar: Calendar = .current) -> [EfficiencyPoint] {
        var cal = calendar
        cal.firstWeekday = 2
        let now = Date()
        return (0..<months).reversed().compactMap { offset -> EfficiencyPoint? in
            let refDate = cal.date(byAdding: .month, value: -offset, to: now) ?? now
            let comps = cal.dateComponents([.year, .month], from: refDate)
            guard let monthStart = cal.date(from: comps),
                  let monthEnd = cal.date(byAdding: .month, value: 1, to: monthStart)
            else { return nil }
            let tops = climbing(sessions)
                .filter { $0.date >= monthStart && $0.date < monthEnd }
                .flatMap(\.ascents)
                .filter { $0.result == .top }
            let flashes = tops.filter { $0.style == .flash }
            return EfficiencyPoint(
                monthStart: monthStart,
                avgAttemptsToTop: tops.isEmpty ? nil : Double(tops.reduce(0) { $0 + $1.attempts }) / Double(tops.count),
                flashRate: tops.isEmpty ? nil : Double(flashes.count) / Double(tops.count)
            )
        }
    }

    // MARK: - A2: Terrain-Heatmap

    struct TerrainCell: Identifiable {
        var id: String { "\(wallAngle.rawValue)_\(holdType.rawValue)" }
        let wallAngle: WallAngle
        let holdType: HoldType
        let sendRate: Double
        let count: Int
    }

    static func terrainSendRates(_ sessions: [ClimbSession]) -> [TerrainCell] {
        let all = climbing(sessions).flatMap(\.ascents)
        var cells: [TerrainCell] = []
        for angle in WallAngle.allCases {
            for hold in HoldType.allCases {
                let group = all.filter { $0.wallAngle == angle && $0.holdType == hold }
                guard !group.isEmpty else { continue }
                let tops = group.filter { $0.result == .top }.count
                cells.append(TerrainCell(
                    wallAngle: angle, holdType: hold,
                    sendRate: Double(tops) / Double(group.count),
                    count: group.count
                ))
            }
        }
        return cells
    }

    // MARK: - A4: Höchstgrad-Trend

    struct GradeTrendPoint: Identifiable {
        let id = UUID()
        let monthStart: Date
        let sortOrder: Int
        let grade: String
        let system: GradeSystem
    }

    static func maxGradeTrend(_ sessions: [ClimbSession], months: Int = 6,
                              calendar: Calendar = .current) -> [GradeTrendPoint] {
        var cal = calendar
        cal.firstWeekday = 2
        let now = Date()
        return (0..<months).reversed().compactMap { offset -> GradeTrendPoint? in
            let refDate = cal.date(byAdding: .month, value: -offset, to: now) ?? now
            let comps = cal.dateComponents([.year, .month], from: refDate)
            guard let monthStart = cal.date(from: comps),
                  let monthEnd = cal.date(byAdding: .month, value: 1, to: monthStart)
            else { return nil }
            let tops = climbing(sessions)
                .filter { $0.date >= monthStart && $0.date < monthEnd }
                .flatMap(\.ascents)
                .filter { $0.result == .top }
            guard let best = tops.max(by: { $0.sortOrder < $1.sortOrder }) else { return nil }
            return GradeTrendPoint(monthStart: monthStart, sortOrder: best.sortOrder,
                                   grade: best.gradeRaw, system: best.gradeSystem)
        }
    }

    // MARK: - A5: Trainingsbelastung & ACWR

    struct WeekLoad: Identifiable {
        let id = UUID()
        let weekStart: Date
        let load: Int
        let acwr: Double?

        var label: String {
            let f = DateFormatter()
            f.locale = Locale(identifier: "de_DE")
            f.dateFormat = "dd.MM."
            return f.string(from: weekStart)
        }
    }

    static func trainingLoad(_ sessions: [ClimbSession], weeks: Int = 8,
                             calendar: Calendar = .current) -> [WeekLoad] {
        var cal = calendar
        cal.firstWeekday = 2
        let now = Date()
        guard let thisWeekStart = cal.dateInterval(of: .weekOfYear, for: now)?.start
        else { return [] }

        let historyWeeks = 8
        var rawLoads: [Int] = []
        var weekStarts: [Date] = []
        for offset in stride(from: historyWeeks - 1, through: 0, by: -1) {
            guard let start = cal.date(byAdding: .weekOfYear, value: -offset, to: thisWeekStart),
                  let end = cal.date(byAdding: .weekOfYear, value: 1, to: start)
            else { continue }
            let inWeek = sessions.filter { $0.date >= start && $0.date < end }
            let load = inWeek.reduce(0) { acc, s in
                acc + (s.perceivedEffort ?? 5) * s.durationMinutes
            }
            rawLoads.append(load)
            weekStarts.append(start)
        }

        let showFrom = max(0, rawLoads.count - weeks)
        var result: [WeekLoad] = []
        for i in showFrom..<rawLoads.count {
            let acuteRange = max(0, i - 3)...i
            let chronicRange = max(0, i - 7)...i
            let acute = Double(rawLoads[acuteRange].reduce(0, +)) / Double(rawLoads[acuteRange].count)
            let chronic = Double(rawLoads[chronicRange].reduce(0, +)) / Double(rawLoads[chronicRange].count)
            result.append(WeekLoad(
                weekStart: weekStarts[i],
                load: rawLoads[i],
                acwr: chronic > 0 ? acute / chronic : nil
            ))
        }
        return result
    }

    // MARK: - W1: Start-Karten

    struct InsightCard: Identifiable {
        let id: String
        let symbol: String
        let title: String
        let value: String
        let subtitle: String
        let color: Color
    }

    static func startCards(_ sessions: [ClimbSession]) -> [InsightCard] {
        var cards: [InsightCard] = []

        let recap = currentWeekRecap(sessions)
        cards.append(InsightCard(
            id: "week", symbol: "calendar.badge.clock", title: "Diese Woche",
            value: "\(recap.tops) Top\(recap.tops == 1 ? "" : "s")",
            subtitle: "\(recap.sessions) Session\(recap.sessions == 1 ? "" : "s") · \(recap.minutes) Min",
            color: Theme.accent
        ))

        let streak = climbWeekStreak(sessions)
        cards.append(InsightCard(
            id: "streak", symbol: "flame.fill", title: "Streak",
            value: "\(streak) Wo\(streak == 1 ? "che" : "chen")",
            subtitle: streak >= 4 ? "Starke Kontinuität!" : streak > 0 ? "Weiter so!" : "Erste Session starten",
            color: streak >= 4 ? Theme.gold : Theme.accent
        ))

        if sessions.count >= 4 {
            let signal = formSignal(sessions)
            var sym = "checkmark.seal.fill"; var title2 = "Gute Form"
            var sub2 = "Belastung und Send-Rate passen gut"; var col2 = Theme.accent
            switch signal {
            case .deloadSuggested:
                sym = "battery.0percent"; title2 = "Erholung"
                sub2 = "RPE hoch – leichter trainieren"; col2 = Theme.danger
            case .techniqueSuggested:
                sym = "figure.mind.and.body"; title2 = "Technik-Fokus"
                sub2 = "Plateau erkannt – Qualität vor Grad"; col2 = Theme.gold
            case .formGood: break
            }
            cards.append(InsightCard(id: "form", symbol: sym, title: title2, value: "", subtitle: sub2, color: col2))
        }

        let weakness = trainingWeakness(sessions)
        if let limiter = weakness.topLimiter {
            cards.append(InsightCard(
                id: "weakness", symbol: "dumbbell.fill", title: "Schwäche",
                value: limiter.label,
                subtitle: weakness.monthlyTrainingCount > 0
                    ? "\(weakness.monthlyTrainingCount)× trainiert diesen Monat"
                    : "Noch nicht gezielt trainiert",
                color: Theme.accent2
            ))
        }

        return cards
    }

    // MARK: - A3: Session-Timeline

    struct TimelinePoint: Identifiable {
        let id = UUID()
        let index: Int
        let cumulativeSendRate: Double
        let isTop: Bool
    }

    static func sessionTimeline(_ session: ClimbSession) -> [TimelinePoint] {
        let sorted = session.ascents.sorted { $0.createdAt < $1.createdAt }
        guard !sorted.isEmpty else { return [] }
        var tops = 0
        return sorted.enumerated().map { i, a in
            if a.result == .top { tops += 1 }
            return TimelinePoint(index: i + 1,
                                 cumulativeSendRate: Double(tops) / Double(i + 1),
                                 isTop: a.result == .top)
        }
    }

    // MARK: - A7.2: Fokus vs. Send-Rate

    struct FocusPerf: Identifiable {
        let id: Int
        let focusRating: Int
        let avgSendRate: Double
        let sessionCount: Int
    }

    static func focusVsPerformance(_ sessions: [ClimbSession]) -> [FocusPerf] {
        var groups: [Int: (sends: Int, total: Int, count: Int)] = [:]
        for s in climbing(sessions) {
            guard let r = s.focusRating, !s.ascents.isEmpty else { continue }
            let tops = s.ascents.filter { $0.result == .top }.count
            var g = groups[r, default: (0, 0, 0)]
            g.sends += tops; g.total += s.ascents.count; g.count += 1
            groups[r] = g
        }
        return groups.map { r, g in
            FocusPerf(id: r, focusRating: r,
                      avgSendRate: g.total > 0 ? Double(g.sends) / Double(g.total) : 0,
                      sessionCount: g.count)
        }.sorted { $0.focusRating < $1.focusRating }
    }

    // MARK: - A8: Outdoor-Bedingungen

    struct ConditionRate: Identifiable {
        let id: String
        let conditions: OutdoorConditions
        let sendRate: Double
        let sessionCount: Int
    }

    static func outdoorConditionRates(_ sessions: [ClimbSession]) -> [ConditionRate] {
        let outdoor = climbing(sessions).filter { $0.outdoor && $0.conditions != nil && !$0.ascents.isEmpty }
        guard !outdoor.isEmpty else { return [] }
        var groups: [OutdoorConditions: (sends: Int, total: Int, count: Int)] = [:]
        for s in outdoor {
            guard let c = s.conditions else { continue }
            let tops = s.ascents.filter { $0.result == .top }.count
            var g = groups[c, default: (0, 0, 0)]
            g.sends += tops; g.total += s.ascents.count; g.count += 1
            groups[c] = g
        }
        return groups.map { c, g in
            ConditionRate(id: c.rawValue, conditions: c,
                          sendRate: g.total > 0 ? Double(g.sends) / Double(g.total) : 0,
                          sessionCount: g.count)
        }.sorted { $0.conditions.rawValue < $1.conditions.rawValue }
    }

    // MARK: - T3: Fingerkraft-Trend (Hangboard)

    struct StrengthPoint: Identifiable {
        let id = UUID()
        let date: Date
        let edgeMM: Int
        let totalWeightKg: Double   // Körpergewicht + Zusatzgewicht (bodyMass + addedWeightKg)
        let note: String?
    }

    static func fingerStrengthTrend(_ sessions: [ClimbSession],
                                    bodyMass: Double? = nil) -> [StrengthPoint] {
        sessions
            .filter { $0.sessionType == .training }
            .flatMap { s in
                s.trainingSets
                    .filter { $0.kind == .hangboardMaxHang && $0.edgeMM != nil }
                    .compactMap { t -> StrengthPoint? in
                        guard let edge = t.edgeMM else { return nil }
                        let added = t.addedWeightKg ?? 0
                        let bw = bodyMass ?? 70
                        return StrengthPoint(
                            date: t.date,
                            edgeMM: edge,
                            totalWeightKg: bw + added,
                            note: t.note
                        )
                    }
            }
            .sorted { $0.date < $1.date }
    }

    // MARK: Erfolge (nur 2 App-Erfolge behalten; Rest in climbAchievements)

    static func achievements(for sessions: [ClimbSession]) -> [Achievement] {
        let total = sessions.count
        let streak = weekStreak(sessions)
        return [
            Achievement(id: "first", title: "Erste Session",
                        subtitle: total >= 1 ? "Erster Zug gemacht!" : "Erste Session starten",
                        symbol: "flag.fill",
                        isUnlocked: total >= 1,
                        progress: min(1, Double(total))),
            Achievement(id: "streak", title: "Wochenstreak",
                        subtitle: streak >= 4 ? "4+ Wochen am Ball!" : "\(streak)/4 Wochen",
                        symbol: "flame.fill",
                        isUnlocked: streak >= 4,
                        progress: min(1, Double(streak) / 4)),
        ]
    }
}
