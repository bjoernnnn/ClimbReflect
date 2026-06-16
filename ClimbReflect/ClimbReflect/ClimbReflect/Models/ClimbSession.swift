import Foundation
import SwiftData

// MARK: - SwiftData-Modell (echte, persistente On-Device-Datenbank)

@Model
final class ClimbSession {
    @Attribute(.unique) var id: UUID
    var workoutUUID: UUID?            // HKWorkout.uuid → Dedupe gegen Doppel-Import aus Redpoint
    var date: Date
    var durationSeconds: Double
    var sessionTypeRaw: String
    var sourceRaw: String

    // Objektive Daten (kommen via HealthKit von Redpoint – alle optional)
    var avgHeartRate: Double?
    var maxHeartRate: Double?
    var activeEnergyKcal: Double?

    // Subjektive Reflexion
    var reflectionCompleted: Bool = false
    var perceivedEffort: Int?         // RPE 1–10
    var limiterRaw: [String] = []     // Limiter.rawValue
    var learned: String?
    var hardestPart: String?
    var improveNext: String?

    // Gym-/Set-Kontext (P3.13)
    var gymName: String?               // z. B. "BoulderWelt München"
    var outdoor: Bool = false

    // Technik-Fokus (P3.6)
    var techniqueFocusRaw: String?     // TechniqueFocus.rawValue
    var focusRating: Int?              // 1–5 Selbstbewertung

    @Relationship(deleteRule: .cascade, inverse: \Ascent.session) var ascents: [Ascent] = []

    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(),
         workoutUUID: UUID? = nil,
         date: Date,
         durationSeconds: Double,
         sessionType: SessionType = .unknown,
         source: SessionSource = .manual,
         avgHeartRate: Double? = nil,
         maxHeartRate: Double? = nil,
         activeEnergyKcal: Double? = nil,
         reflectionCompleted: Bool = false,
         perceivedEffort: Int? = nil,
         limiters: [Limiter] = [],
         learned: String? = nil,
         hardestPart: String? = nil,
         improveNext: String? = nil,
         techniqueFocus: TechniqueFocus? = nil,
         focusRating: Int? = nil,
         gymName: String? = nil,
         outdoor: Bool = false) {
        self.id = id
        self.workoutUUID = workoutUUID
        self.date = date
        self.durationSeconds = durationSeconds
        self.sessionTypeRaw = sessionType.rawValue
        self.sourceRaw = source.rawValue
        self.avgHeartRate = avgHeartRate
        self.maxHeartRate = maxHeartRate
        self.activeEnergyKcal = activeEnergyKcal
        self.reflectionCompleted = reflectionCompleted
        self.perceivedEffort = perceivedEffort
        self.limiterRaw = limiters.map(\.rawValue)
        self.learned = learned
        self.hardestPart = hardestPart
        self.improveNext = improveNext
        self.techniqueFocusRaw = techniqueFocus?.rawValue
        self.focusRating = focusRating
        self.gymName = gymName
        self.outdoor = outdoor
        self.createdAt = .now
        self.updatedAt = .now
    }
}

// MARK: - Komfort-Helfer

extension ClimbSession {
    var sessionType: SessionType { SessionType(rawValue: sessionTypeRaw) ?? .unknown }
    var source: SessionSource { SessionSource(rawValue: sourceRaw) ?? .manual }
    var limiters: [Limiter] { limiterRaw.compactMap(Limiter.init(rawValue:)) }
    var durationMinutes: Int { Int(durationSeconds / 60) }
    var techniqueFocus: TechniqueFocus? { techniqueFocusRaw.flatMap(TechniqueFocus.init(rawValue:)) }
    var isClimbing: Bool { sessionType != .training }
}
