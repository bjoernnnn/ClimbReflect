import Foundation
import SwiftData

// MARK: - Mock-Daten (Startbefüllung der echten SwiftData-DB)
//
// Beim ersten App-Start werden diese Sessions in die persistente Datenbank
// geschrieben. Danach lädt die App immer aus der DB. Später ersetzt/ergänzt
// der Redpoint-Import (HealthKit) diese Daten – die Mock-Sessions bleiben als
// `source = .manual` erhalten.

enum MockData {

    static func seedIfNeeded(_ context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<ClimbSession>())) ?? 0
        guard count == 0 else { return }
        for session in makeSessions() { context.insert(session) }
        try? context.save()
    }

    /// 14 Sessions über die letzten ~8 Wochen, gemischt.
    static func makeSessions() -> [ClimbSession] {
        let cal = Calendar.current
        let now = Date()
        func daysAgo(_ d: Int, hour: Int = 18) -> Date {
            guard let base = cal.date(byAdding: .day, value: -d, to: now) else { return now }
            return cal.date(bySettingHour: hour, minute: 0, second: 0, of: base) ?? base
        }

        // (TageZurück, Stunde, Typ, Minuten, RPE, Limiter)
        let plan: [(Int, Int, SessionType, Int, Int, [Limiter])] = [
            (2,  18, .boulder, 75,  7, [.fingerStrength, .mental]),
            (4,  19, .lead,    90,  8, [.endurance]),
            (7,   8, .boulder, 60,  6, [.technique]),               // Frühaufsteher
            (9,  18, .topRope, 50,  5, [.mobility]),
            (12, 19, .lead,    95,  8, [.endurance, .mental]),
            (15, 18, .boulder, 70,  7, [.beta, .fingerStrength]),
            (18, 17, .training,45,  6, [.fingerStrength]),
            (21, 19, .lead,   130,  9, [.endurance]),               // Ausdauerheld (≥120 Min)
            (24, 18, .boulder, 65,  6, [.technique, .mental]),
            (28, 18, .topRope, 55,  5, [.mobility]),
            (33, 19, .boulder, 80,  7, [.fingerStrength]),
            (38, 18, .lead,    85,  7, [.beta]),
            (45, 18, .boulder, 60,  6, [.technique]),
            (52, 19, .training,40,  5, [.fingerStrength])
        ]

        return plan.map { d, hour, type, minutes, rpe, limiters in
            ClimbSession(
                date: daysAgo(d, hour: hour),
                durationSeconds: Double(minutes * 60),
                sessionType: type,
                source: .manual,
                avgHeartRate: Double(120 + rpe * 4),
                maxHeartRate: Double(150 + rpe * 5),
                activeEnergyKcal: Double(minutes) * 7.5,
                reflectionCompleted: true,
                perceivedEffort: rpe,
                limiters: limiters,
                learned: "Mock-Eintrag",
                hardestPart: nil,
                improveNext: nil
            )
        }
    }

    // MARK: - DS-5: Preview-Szenarien für den Fortschritt-Tab (deterministisch,
    // keine Zufallsdaten — dienen als Abnahme-Netz gegen Layout-Brüche).

    /// Voller Fortschritt-Tab: 12 Monate Boulder-Progression bis zum aktuellen
    /// PB (im Zeitraum → Gold-Feier), 6 Erst-Sends in den letzten 6 Monaten
    /// (zeigt den „+N"-Überhang der Fakten-Karte), Wohlfühl-Kandidat bei 7A.
    static func makeFullProgressScenario() -> [ClimbSession] {
        let cal = Calendar.current
        let now = Date()
        func daysAgo(_ d: Int) -> Date { cal.date(byAdding: .day, value: -d, to: now) ?? now }

        func session(_ days: Int, _ grade: String) -> ClimbSession {
            let date = daysAgo(days)
            let s = ClimbSession(date: date, durationSeconds: 3600, sessionType: .boulder)
            let top = Ascent(gradeSystem: .fontainebleau, grade: grade, result: .top, date: date)
            top.session = s
            s.ascents.append(top)
            return s
        }

        let sevenA = session(150, "7A")
        // Wohlfühl-Kandidat: 3 zusätzliche Fehlversuche auf demselben Grad
        // → 4/5, ohne minSampleSize (5) zu erreichen.
        for _ in 0..<3 {
            let fail = Ascent(gradeSystem: .fontainebleau, grade: "7A", result: .attempt, date: sevenA.date)
            fail.session = sevenA
            sevenA.ascents.append(fail)
        }

        return [
            session(330, "6A"), session(300, "6A+"), session(270, "6B"), session(240, "6B+"),
            session(210, "6C"), session(180, "6C+"), sevenA, session(120, "7A+"),
            session(90, "7B"), session(60, "7B+"), session(30, "7C"), session(5, "8A")
        ]
    }

    /// Spärlicher Fortschritt-Tab: 2 Sessions, 1 Erst-Send im Zeitraum, kein
    /// Wohlfühl-Grad (nur Kandidat, n = 1).
    static func makeSparseProgressScenario() -> [ClimbSession] {
        let cal = Calendar.current
        let now = Date()
        func daysAgo(_ d: Int) -> Date { cal.date(byAdding: .day, value: -d, to: now) ?? now }

        func session(_ days: Int, _ grade: String) -> ClimbSession {
            let date = daysAgo(days)
            let s = ClimbSession(date: date, durationSeconds: 3600, sessionType: .boulder)
            let top = Ascent(gradeSystem: .fontainebleau, grade: grade, result: .top, date: date)
            top.session = s
            s.ascents.append(top)
            return s
        }

        return [session(200, "6A"), session(10, "6B")]
    }
}
