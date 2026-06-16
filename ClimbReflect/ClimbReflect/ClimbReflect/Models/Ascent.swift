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
         session: ClimbSession? = nil) {
        self.id = id
        self.gradeSystemRaw = gradeSystem.rawValue
        self.gradeRaw = grade
        self.resultRaw = result.rawValue
        self.styleRaw = style?.rawValue
        self.attempts = attempts
        self.note = note
        self.date = date
        self.session = session
        self.createdAt = .now
    }
}

extension Ascent {
    var gradeSystem: GradeSystem { GradeSystem(rawValue: gradeSystemRaw) ?? .fontainebleau }
    var result: AscentResult { AscentResult(rawValue: resultRaw) ?? .attempt }
    var style: AscentStyle? { styleRaw.flatMap(AscentStyle.init(rawValue:)) }
    var sortOrder: Int { gradeSystem.sortOrder(of: gradeRaw) }
}
