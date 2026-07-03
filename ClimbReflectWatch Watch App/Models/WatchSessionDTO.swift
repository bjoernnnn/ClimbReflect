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
        let durationSeconds: Double?
        let heartRateAtBanking: Double?   // RP-6: HF-Snapshot beim Banken (optional → alte DTOs)
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

    // RP-3: Workout-Pausenzeit (brutto durationSeconds bleibt die volle Session-
    // Spanne; Aktivzeit = durationSeconds − pausedSeconds). Optional → alte DTOs
    // dekodieren als nil (= 0).
    let pausedSeconds: Double?

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
            pausedSeconds: pausedSeconds,
            // RP-2: focus ist bei Training immer nil (skipFocus) – dann den in
            // endWorkout() gesetzten focusRaw (Zielkapazität) NICHT überschreiben.
            rpe: rpe, focusRaw: focus?.rawValue ?? self.focusRaw, energyRaw: energy?.rawValue
        )
    }
}
