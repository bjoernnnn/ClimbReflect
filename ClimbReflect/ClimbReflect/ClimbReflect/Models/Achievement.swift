import Foundation

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


// MARK: - Engine: Session-Insights & Rückblick

// StatsEngine = Session-Insights (insights/sessionTimeline), Wochen-Streak
// (inkl. unverlierbarer Rekord) und der "Damals"-Rückblick. Erfolge sind seit
// ERFOLGE-KONZEPT-V2 persistierte Ereignisse aus der AchievementEngine (S34) —
// nicht mehr hier. Fortschritt-Auswertungen (Level/Verlauf/Pyramide/Volumen/
// Stil) leben in ProgressEngine (FORTSCHRITT-KONZEPT.md). Alle drei Engines
// sind überschneidungsfrei: Grad-/Zeitraum-Analytik nur in ProgressEngine,
// Erfolgs-Logik nur in AchievementEngine, Rückblick-/Insights-Logik nur hier.

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

}
