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
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "dd.MM."
        return f.string(from: weekStart)
    }
}

// MARK: - Engine: leitet Statistik, Wochenverlauf und Erfolge aus den Sessions ab

enum StatsEngine {

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

    static func totalMinutes(_ sessions: [ClimbSession]) -> Int {
        sessions.reduce(0) { $0 + $1.durationMinutes }
    }

    static func sessionsThisWeek(_ sessions: [ClimbSession]) -> Int {
        weeklyMinutes(sessions, weeks: 1).first?.sessions ?? 0
    }

    // MARK: Erfolge

    static func achievements(for sessions: [ClimbSession]) -> [Achievement] {
        let total = sessions.count
        let streak = weekStreak(sessions)
        let distinctTypes = Set(sessions.map(\.sessionTypeRaw)
            .filter { $0 != SessionType.unknown.rawValue }).count
        let longest = sessions.map(\.durationMinutes).max() ?? 0
        let earlyBird = sessions.contains {
            Calendar.current.component(.hour, from: $0.date) < 9
        }

        func milestone(_ id: String, _ title: String, _ symbol: String,
                       have: Int, need: Int) -> Achievement {
            Achievement(id: id, title: title,
                        subtitle: have >= need ? "Geschafft" : "\(have)/\(need) Sessions",
                        symbol: symbol,
                        isUnlocked: have >= need,
                        progress: min(1, Double(have) / Double(need)))
        }

        return [
            milestone("first",   "Erster Zug",   "flag.fill",            have: total, need: 1),
            milestone("five",    "Warmgeklettert","figure.climbing",     have: total, need: 5),
            milestone("ten",     "Stammgast",    "medal.fill",           have: total, need: 10),
            milestone("twenty",  "Eisern",       "trophy.fill",          have: total, need: 20),
            Achievement(id: "streak", title: "Wochenstreak",
                        subtitle: streak >= 4 ? "Geschafft" : "\(streak)/4 Wochen",
                        symbol: "flame.fill",
                        isUnlocked: streak >= 4,
                        progress: min(1, Double(streak) / 4)),
            Achievement(id: "versatile", title: "Vielseitig",
                        subtitle: distinctTypes >= 3 ? "Geschafft" : "\(distinctTypes)/3 Arten",
                        symbol: "square.grid.2x2.fill",
                        isUnlocked: distinctTypes >= 3,
                        progress: min(1, Double(distinctTypes) / 3)),
            Achievement(id: "marathon", title: "Ausdauerheld",
                        subtitle: longest >= 120 ? "Geschafft" : "\(longest)/120 Min",
                        symbol: "hourglass",
                        isUnlocked: longest >= 120,
                        progress: min(1, Double(longest) / 120)),
            Achievement(id: "earlybird", title: "Frühaufsteher",
                        subtitle: earlyBird ? "Geschafft" : "Vor 9 Uhr klettern",
                        symbol: "sunrise.fill",
                        isUnlocked: earlyBird,
                        progress: earlyBird ? 1 : 0)
        ]
    }
}
