import Foundation

// Codable-DTO für WatchConnectivity-Transfer Watch → iPhone
// Muss identisch zur Watch-seitigen WatchSessionDTO bleiben.
// nonisolated: Typ wird in nonisolated WC-Callback verwendet (SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor im Target)

struct WatchSessionDTO: Codable, Sendable {
    struct AscentDTO: Codable {
        let id: UUID
        let gradeSystemRaw: String
        let gradeRaw: String?
        let resultRaw: String?
        let styleRaw: String?
        let attempts: Int
        let altitudeGain: Double
        let durationSeconds: Double?
        let date: Date
        let sessionTypeRaw: String
        let projectName: String?
        let projectID: UUID?
        // SH-5: Schuh-Cache (optional → alte DTOs dekodieren weiter)
        let shoeName: String?
        let shoeID: UUID?
        let shoeCondition: String?  // ShoeCondition.rawValue Snapshot
    }

    let id: UUID
    let workoutUUID: UUID?
    let date: Date
    let durationSeconds: Double
    let sessionTypeRaw: String
    let avgHeartRate: Double?
    let maxHeartRate: Double?
    let activeEnergyKcal: Double?
    let altitudeTotalGain: Double
    let ascents: [AscentDTO]

    // Fragebogen (optional — fehlende Felder werden als nil dekodiert)
    let rpe: Int?
    let focusRaw: String?
    let energyRaw: String?

    nonisolated static let transferKey = "watchSessionDTO"
}
