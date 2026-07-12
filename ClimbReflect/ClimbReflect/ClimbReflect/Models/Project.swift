import Foundation
import SwiftData

@Model
final class Project {
    // CK-P0: .unique entfernt + Defaults ergänzt (CloudKit-Voraussetzungen).
    var id: UUID = UUID()
    var name: String = ""
    var betaNotes: String = ""
    var statusRaw: String?              // nil = auto-abgeleitet, "abandoned" = manuell
    var isPinned: Bool = false
    var gradeSystemRaw: String?
    var targetGradeRaw: String?
    var createdAt: Date = Date.now

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

    var totalAttempts: Int { ascents.reduce(0) { $0 + $1.attempts } }
    var distinctDays: Int {
        Set(ascents.map { Calendar.current.startOfDay(for: $0.date) }).count
    }
    var bestTopGrade: String? {
        ascents.filter { $0.result == .top }
            .max { $0.canonicalOrder < $1.canonicalOrder }?.gradeRaw
    }
    var sentOn: Date? {
        ascents.filter { $0.result == .top }.map(\.date).min()
    }
    var lastAttempt: Date {
        ascents.map(\.date).max() ?? .distantPast
    }

    // FB-1: Projekt-Grad als Stammdatum
    var gradeSystem: GradeSystem? { gradeSystemRaw.flatMap(GradeSystem.init(rawValue:)) }
    var hasTargetGrade: Bool { targetGradeRaw != nil && gradeSystem != nil }
    /// Ziel-Grad ins Anzeige-System umgerechnet (nil, wenn kein Grad festgelegt).
    var displayTargetGrade: String? {
        guard let raw = targetGradeRaw, let sys = gradeSystem else { return nil }
        return GradeConverter.display(grade: raw, storedIn: sys)
    }

    // GR-1: repräsentativer Grad für die Watch-Vorbelegung beim Klassifizieren.
    // Bevorzugt den Ziel-Grad; sonst der schwerste getoppte Grad; sonst der
    // schwerste versuchte. Viele Projekte haben keinen Ziel-Grad — ohne diesen
    // Fallback bekäme die Watch dort gar nichts und griffe auf ihren eigenen,
    // irreführenden Leiter-Mitte-Fallback zurück (S. AttemptLogView).
    var representativeGradeRaw: String? {
        if let target = targetGradeRaw { return target }
        let topped = ascents.filter { $0.result == .top }
        let pool = topped.isEmpty ? ascents : topped
        return pool.max(by: { $0.canonicalOrder < $1.canonicalOrder })?.gradeRaw
    }
    var representativeGradeSystemRaw: String? {
        gradeSystemRaw ?? ascents.first?.gradeSystemRaw
    }

    init(name: String, betaNotes: String = "", statusRaw: String? = nil, isPinned: Bool = false) {
        self.id = UUID()
        self.name = name
        self.betaNotes = betaNotes
        self.statusRaw = statusRaw
        self.isPinned = isPinned
        self.createdAt = .now
    }
}
