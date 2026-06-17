import Foundation

// Codable-DTO für WatchConnectivity-Transfer Watch → iPhone

struct WatchSessionDTO: Codable, Sendable {
    struct AscentDTO: Codable {
        let id: UUID
        let gradeSystemRaw: String
        let gradeRaw: String?
        let resultRaw: String?
        let styleRaw: String?
        let attempts: Int
        let altitudeGain: Double
        let date: Date
        let sessionTypeRaw: String
        let projectName: String?
        let projectID: UUID?
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

    // Fragebogen (optional — ältere Empfänger ignorieren diese Felder)
    let rpe: Int?
    let focusRaw: String?
    let energyRaw: String?

    nonisolated static let transferKey = "watchSessionDTO"

    // Kopie mit Fragebogen-Antworten
    func withQuestionnaire(rpe: Int?, focus: WatchSessionFocus?, energy: WatchSessionEnergy?) -> WatchSessionDTO {
        WatchSessionDTO(
            id: id, workoutUUID: workoutUUID, date: date,
            durationSeconds: durationSeconds, sessionTypeRaw: sessionTypeRaw,
            avgHeartRate: avgHeartRate, maxHeartRate: maxHeartRate,
            activeEnergyKcal: activeEnergyKcal, altitudeTotalGain: altitudeTotalGain,
            ascents: ascents,
            rpe: rpe, focusRaw: focus?.rawValue, energyRaw: energy?.rawValue
        )
    }
}
