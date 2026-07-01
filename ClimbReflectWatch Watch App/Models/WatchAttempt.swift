import Foundation

// In-Memory Versuch während einer laufenden Watch-Session

struct WatchAttempt: Identifiable {
    let id: UUID
    var gradeSystem: WatchGradeSystem
    var grade: String?
    var result: WatchAscentResult?
    var style: WatchAscentStyle?
    var attempts: Int
    var altitudeGain: Double
    var durationSeconds: Double?
    var heartRateAtBanking: Double?   // Snapshot der HF zum Zeitpunkt des Bankens
    var note: String?
    var date: Date
    var sessionType: WatchSessionType
    var projectInfo: ProjectInfo?     // Snapshot des aktiven Projekts zum Zeitpunkt des Bankens
    var shoeInfo: ShoeInfo?           // Snapshot des aktiven Schuhs zum Zeitpunkt des Bankens

    init(gradeSystem: WatchGradeSystem,
         grade: String? = nil,
         result: WatchAscentResult? = nil,
         style: WatchAscentStyle? = nil,
         attempts: Int = 1,
         altitudeGain: Double = 0,
         durationSeconds: Double? = nil,
         heartRateAtBanking: Double? = nil,
         note: String? = nil,
         sessionType: WatchSessionType = .boulder,
         projectInfo: ProjectInfo? = nil,
         shoeInfo: ShoeInfo? = nil) {
        self.id = UUID()
        self.gradeSystem = gradeSystem
        self.grade = grade
        self.result = result
        self.style = style
        self.attempts = attempts
        self.altitudeGain = altitudeGain
        self.durationSeconds = durationSeconds
        self.heartRateAtBanking = heartRateAtBanking
        self.note = note
        self.date = .now
        self.sessionType = sessionType
        self.projectInfo = projectInfo
        self.shoeInfo = shoeInfo
    }

    init(fromDTO dto: WatchSessionDTO.AscentDTO, sessionType: WatchSessionType) {
        self.id          = dto.id
        self.gradeSystem = WatchGradeSystem(rawValue: dto.gradeSystemRaw) ?? sessionType.defaultGradeSystem
        self.grade       = dto.gradeRaw
        self.result      = dto.resultRaw.flatMap(WatchAscentResult.init)
        self.style       = dto.styleRaw.flatMap(WatchAscentStyle.init)
        self.attempts    = dto.attempts
        self.altitudeGain = dto.altitudeGain
        self.durationSeconds = dto.durationSeconds
        self.heartRateAtBanking = nil
        self.note        = nil
        self.date        = dto.date
        self.sessionType = sessionType
        if let name = dto.projectName {
            let id = dto.projectID?.uuidString ?? name
            self.projectInfo = ProjectInfo(id: id, name: name)
        } else {
            self.projectInfo = nil
        }
        if let name = dto.shoeName {
            let id = dto.shoeID?.uuidString ?? name
            self.shoeInfo = ShoeInfo(id: id, name: name, condition: dto.shoeCondition, defaultForTypes: [])
        } else {
            self.shoeInfo = nil
        }
    }

    var isComplete: Bool { grade != nil && result != nil }

    func toDTO() -> WatchSessionDTO.AscentDTO {
        WatchSessionDTO.AscentDTO(
            id: id,
            gradeSystemRaw: gradeSystem.rawValue,
            gradeRaw: grade,
            resultRaw: result?.rawValue,
            styleRaw: style?.rawValue,
            attempts: attempts,
            altitudeGain: altitudeGain,
            durationSeconds: durationSeconds,
            date: date,
            sessionTypeRaw: sessionType.rawValue,
            projectName: projectInfo?.name,
            projectID: projectInfo.flatMap { UUID(uuidString: $0.id) },
            shoeName: shoeInfo?.name,
            shoeID: shoeInfo.flatMap { UUID(uuidString: $0.id) },
            shoeCondition: shoeInfo?.condition
        )
    }
}
