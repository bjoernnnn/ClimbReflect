import Foundation
import SwiftData

@Model
final class Ascent {
    @Attribute(.unique) var id: UUID
    var gradeSystemRaw: String
    var gradeRaw: String
    var resultRaw: String
    var styleRaw: String?
    var attempts: Int
    var note: String?
    var date: Date

    // Stil-Tags (P3.7)
    var wallAngleRaw: String?
    var holdTypeRaw: String?
    var climbStyleRaw: String?

    // Projekt-Zugehörigkeit: projectName als Migration-Cache, project als echte Relation
    var projectName: String?
    var project: Project?

    // Kletterhöhe (B1 – Watch-Barometer, optional manuell)
    var altitudeGain: Double = 0
    // Versuchdauer aus dem Action-Button-Flow (optional, nur Watch)
    var durationSeconds: Double?

    // Schuh-Zugehörigkeit: shoeName als Cache, shoe als echte Relation (SH-1)
    var shoeName: String?
    var shoe: Shoe?

    // Gym-/Set-Kontext (P3.13)
    var setName: String?               // z. B. "Gelb rechts", "Sektor B"

    // Medien (P3.11) — externalStorage hält die SwiftData-Hauptdatei klein
    @Attribute(.externalStorage) var photoData: Data?

    var session: ClimbSession?
    var createdAt: Date

    init(id: UUID = UUID(),
         gradeSystem: GradeSystem,
         grade: String,
         result: AscentResult,
         style: AscentStyle? = nil,
         attempts: Int = 1,
         note: String? = nil,
         date: Date = .now,
         wallAngle: WallAngle? = nil,
         holdType: HoldType? = nil,
         climbStyle: ClimbStyle? = nil,
         projectName: String? = nil,
         session: ClimbSession? = nil) {
        self.id = id
        self.gradeSystemRaw = gradeSystem.rawValue
        self.gradeRaw = grade
        self.resultRaw = result.rawValue
        self.styleRaw = style?.rawValue
        self.attempts = attempts
        self.note = note
        self.date = date
        self.wallAngleRaw = wallAngle?.rawValue
        self.holdTypeRaw = holdType?.rawValue
        self.climbStyleRaw = climbStyle?.rawValue
        self.projectName = projectName
        self.session = session
        self.createdAt = .now
    }
}

extension Ascent {
    var gradeSystem: GradeSystem { GradeSystem(rawValue: gradeSystemRaw) ?? .fontainebleau }
    var result: AscentResult { AscentResult(rawValue: resultRaw) ?? .attempt }
    var style: AscentStyle? { styleRaw.flatMap(AscentStyle.init(rawValue:)) }
    var wallAngle: WallAngle? { wallAngleRaw.flatMap(WallAngle.init(rawValue:)) }
    var holdType: HoldType? { holdTypeRaw.flatMap(HoldType.init(rawValue:)) }
    var climbStyle: ClimbStyle? { climbStyleRaw.flatMap(ClimbStyle.init(rawValue:)) }
    var sortOrder: Int { gradeSystem.sortOrder(of: gradeRaw) }
}
