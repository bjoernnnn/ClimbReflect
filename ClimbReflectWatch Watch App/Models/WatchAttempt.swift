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
    var heartRateAtBanking: Double?   // Snapshot der HF zum Zeitpunkt des Bankens
    var note: String?
    var date: Date
    var sessionType: WatchSessionType
    var projectInfo: ProjectInfo?     // Snapshot des aktiven Projekts zum Zeitpunkt des Bankens

    init(gradeSystem: WatchGradeSystem,
         grade: String? = nil,
         result: WatchAscentResult? = nil,
         style: WatchAscentStyle? = nil,
         attempts: Int = 1,
         altitudeGain: Double = 0,
         heartRateAtBanking: Double? = nil,
         note: String? = nil,
         sessionType: WatchSessionType = .boulder,
         projectInfo: ProjectInfo? = nil) {
        self.id = UUID()
        self.gradeSystem = gradeSystem
        self.grade = grade
        self.result = result
        self.style = style
        self.attempts = attempts
        self.altitudeGain = altitudeGain
        self.heartRateAtBanking = heartRateAtBanking
        self.note = note
        self.date = .now
        self.sessionType = sessionType
        self.projectInfo = projectInfo
    }

    init(fromDTO dto: WatchSessionDTO.AscentDTO, sessionType: WatchSessionType) {
        self.id          = dto.id
        self.gradeSystem = WatchGradeSystem(rawValue: dto.gradeSystemRaw) ?? sessionType.defaultGradeSystem
        self.grade       = dto.gradeRaw
        self.result      = dto.resultRaw.flatMap(WatchAscentResult.init)
        self.style       = dto.styleRaw.flatMap(WatchAscentStyle.init)
        self.attempts    = dto.attempts
        self.altitudeGain = dto.altitudeGain
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
            date: date,
            sessionTypeRaw: sessionType.rawValue,
            projectName: projectInfo?.name,
            projectID: projectInfo.flatMap { UUID(uuidString: $0.id) }
        )
    }
}
