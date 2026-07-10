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


// MARK: - Engine: Erfolge & Session-Insights
//
// StatsEngine = Erfolge (climbAchievements/achievements) & Session-Insights
// (insights/sessionTimeline) + Wochen-Streak. Fortschritt-Auswertungen
// (Level/Verlauf/Pyramide/Volumen/Stil) leben in ProgressEngine (FORTSCHRITT-
// KONZEPT.md). Beide Engines sind überschneidungsfrei: Grad-/Zeitraum-Analytik
// nur in ProgressEngine, Belohnungs-/Rückblick-Logik nur hier.

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
    /// Die laufende Woche zählt mit, bricht den Streak aber nicht ab, solange sie
    /// noch leer ist (montags stünde sonst jeder Streak sofort auf 0).
    static func weekStreak(_ sessions: [ClimbSession], calendar: Calendar = .current) -> Int {
        var weeks = Array(weeklyMinutes(sessions, weeks: 26, calendar: calendar).reversed())
        if weeks.first?.sessions == 0 { weeks.removeFirst() }
        var streak = 0
        for point in weeks {
            if point.sessions > 0 { streak += 1 } else { break }
        }
        return streak
    }

    /// Wie weekStreak, aber nur Klettersessions (Training ausgeschlossen).
    static func climbWeekStreak(_ sessions: [ClimbSession], calendar: Calendar = .current) -> Int {
        weekStreak(climbing(sessions), calendar: calendar)
    }

    /// Längster Kletter-Wochen-Streak der Gesamthistorie (Montag-Wochen).
    /// Unverlierbarer Rekord (MO-5): entkoppelt von `weeklyMinutes` (dessen
    /// 26-Wochen-Fenster reicht für die volle Historie nicht). Über die Menge der
    /// Wochen-Startdaten, längster Lauf aufeinanderfolgender Wochen per Datums-
    /// (nicht KW-)Arithmetik → ein Jahreswechsel-Lauf (KW 52 → KW 1) bleibt ein Lauf.
    static func bestClimbWeekStreak(_ sessions: [ClimbSession],
                                    calendar: Calendar = .current) -> Int {
        var cal = calendar
        cal.firstWeekday = 2 // Montag
        let weekStarts = Set(climbing(sessions).compactMap {
            cal.dateInterval(of: .weekOfYear, for: $0.date)?.start
        }).sorted()
        guard !weekStarts.isEmpty else { return 0 }

        var best = 1, run = 1
        for i in 1..<weekStarts.count {
            if let next = cal.date(byAdding: .weekOfYear, value: 1, to: weekStarts[i - 1]),
               cal.isDate(next, inSameDayAs: weekStarts[i]) {
                run += 1
                best = max(best, run)
            } else {
                run = 1
            }
        }
        return best
    }

    // MARK: - MO-12: „Damals"-Rückblick (deterministische Wochen-Rotation)

    /// Deterministische Wochen-Rotation über geeignete Rückblick-Sessions
    /// (Kletter-Session, ≥ 90 Tage alt, `learned` oder `hardestPart` nicht leer).
    /// Index = (yearForWeekOfYear · 100 + weekOfYear) mod Anzahl → mehrfaches
    /// Öffnen in derselben Woche zeigt dieselbe Karte (kein Checking-Anreiz, S33),
    /// die Folgewoche rotiert weiter. Kandidaten aufsteigend nach Datum (stabiler Index).
    static func throwbackSession(_ sessions: [ClimbSession],
                                 calendar: Calendar = .current,
                                 now: Date = Date()) -> ClimbSession? {
        guard let cutoff = calendar.date(byAdding: .day, value: -90, to: now) else { return nil }
        let candidates = climbing(sessions)
            .filter { $0.date <= cutoff && hasThrowbackText($0) }
            .sorted { $0.date < $1.date }
        guard !candidates.isEmpty else { return nil }

        let comps = calendar.dateComponents([.weekOfYear, .yearForWeekOfYear], from: now)
        let key = (comps.yearForWeekOfYear ?? 0) * 100 + (comps.weekOfYear ?? 0)
        return candidates[key % candidates.count]
    }

    private static func hasThrowbackText(_ s: ClimbSession) -> Bool {
        !(s.learned ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !(s.hardestPart ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

        // Neuer Höchstgrad (canonicalOrder: skalenübergreifend vergleichbar)
        // RP-5: nur bewertete Tops – "?" darf kein Höchstgrad werden
        let maxGrade = tops.filter { $0.isGraded }.max { $0.canonicalOrder < $1.canonicalOrder }

        // 3 Flashes in einer Session
        let bestFlashSession = climbSessions
            .map { ($0, $0.ascents.filter { $0.style == .flash }.count) }
            .max { $0.1 < $1.1 }

        // Projekt gesendet (> 5 Versuche) – echte Relation zuerst, Name nur als
        // Migrations-Fallback (projectName ist nach der Projekt-Migration oft nil)
        func projectKey(_ a: Ascent) -> String? { a.project?.name ?? a.projectName }
        let projectSent = tops.first { a in
            guard let name = projectKey(a) else { return false }
            let totalAttempts = allAscents
                .filter { projectKey($0) == name }
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
                subtitle: projectSent.flatMap(projectKey).map { "Projekt \($0) gesendet!" }
                    ?? "Projekt mit 5+ Versuchen senden",
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
        let hardestTopGradeSystem: GradeSystem?   // RP-17: für Anzeige-Umrechnung
        let timedAscentCount: Int                 // FB-10: Ascents mit erfasster Dauer
        let ascentCount: Int                      // FB-10: alle Ascents
        // FB-10: Zeitaufteilung nur bei voller Abdeckung sinnvoll (sonst zählen
        // ungetimte Ascents implizit als Pause und verzerren den Aktiv-Anteil).
        var hasFullTimeCoverage: Bool { ascentCount > 0 && timedAscentCount == ascentCount }
    }

    static func insights(for session: ClimbSession) -> SessionInsights {
        let ascents = session.ascents
        let timed = ascents.compactMap(\.durationSeconds).filter { $0 > 0 }
        let activeRaw = timed.reduce(0, +)
        let active = min(activeRaw, session.durationSeconds)
        let hasAttemptTimes = !timed.isEmpty

        let tops = ascents.filter { $0.result == .top }
        let total = session.durationSeconds
        // RP-3: Trainingslast & Erfolgsrate pro Zeit rechnen mit Aktivzeit (ohne Pausen)
        let activeTime = session.activeSeconds
        let sendsPerHour: Double? = activeTime > 0 && !tops.isEmpty
            ? Double(tops.count) / (activeTime / 3600)
            : nil

        let load = session.perceivedEffort.map { Int(Double($0) * activeTime / 60) }

        let successRate: Double? = ascents.isEmpty ? nil
            : Double(tops.count) / Double(ascents.count)

        let attemptsPerSend: Double? = tops.isEmpty ? nil
            : Double(tops.reduce(0) { $0 + $1.attempts }) / Double(tops.count)

        let hardestTop = tops.filter { $0.isGraded }
            .max(by: { $0.canonicalOrder < $1.canonicalOrder })  // RP-5
        let hardestTopGrade = hardestTop?.gradeRaw

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
            hardestTopGrade: hardestTopGrade,
            hardestTopGradeSystem: hardestTop?.gradeSystem,
            timedAscentCount: timed.count,   // FB-10
            ascentCount: ascents.count
        )
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
