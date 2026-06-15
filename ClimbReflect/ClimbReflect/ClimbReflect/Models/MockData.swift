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
            let base = cal.date(byAdding: .day, value: -d, to: now)!
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
}
