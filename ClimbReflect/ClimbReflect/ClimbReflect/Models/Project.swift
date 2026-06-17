import Foundation
import SwiftData

@Model
final class Project {
    @Attribute(.unique) var id: UUID
    var name: String
    var betaNotes: String = ""
    var statusRaw: String?              // nil = auto-abgeleitet, "abandoned" = manuell
    var isPinned: Bool = false
    var gradeSystemRaw: String?
    var targetGradeRaw: String?
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \Ascent.project)
    var ascents: [Ascent] = []

    @Relationship(deleteRule: .cascade, inverse: \ProjectMedia.project)
    var media: [ProjectMedia] = []

    enum Status: String { case active, sent, abandoned }

    var isSent: Bool {
        if statusRaw == Status.abandoned.rawValue { return false }
        return ascents.contains { $0.result == .top }
    }
    var isAbandoned: Bool { statusRaw == Status.abandoned.rawValue }
    var isActive: Bool { !isSent && !isAbandoned }

    init(name: String, betaNotes: String = "", statusRaw: String? = nil, isPinned: Bool = false) {
        self.id = UUID()
        self.name = name
        self.betaNotes = betaNotes
        self.statusRaw = statusRaw
        self.isPinned = isPinned
        self.createdAt = .now
    }
}
