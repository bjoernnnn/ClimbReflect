import Foundation

// VT-4/E4: Grad-Vorbelegung beim Erfassen mit einer echten Grundlage statt
// einem fixen Fb-6A-Default (der z. B. in Seil-Sessions falsch war).
enum GradeDefaults {
    static func discipline(for type: SessionType) -> ProgressEngine.Discipline {
        switch type {
        case .lead, .topRope, .autoBelay: .rope
        default: .boulder
        }
    }

    /// E4: Projekt → letzte Begehung der Session → letzte Begehung der Disziplin → niedrigster Grad (S37).
    static func initial(session: ClimbSession, project: Project?,
                        allSessions: [ClimbSession]) -> (system: GradeSystem, grade: String) {
        let discipline = discipline(for: session.sessionType)
        let target = discipline.displaySystem

        func converted(_ raw: String, _ system: GradeSystem) -> (GradeSystem, String)? {
            GradeConverter.convert(grade: raw, from: system, to: target).map { (target, $0) }
        }

        if let project, let raw = project.representativeGradeRaw,
           let sysRaw = project.representativeGradeSystemRaw, let sys = GradeSystem(rawValue: sysRaw),
           sys.isBoulder == discipline.isBoulder, let r = converted(raw, sys) { return r }

        let latest: ([Ascent]) -> Ascent? = { ascents in
            ascents.filter { $0.isGraded && discipline.matches($0) }
                   .max { ($0.date, $0.createdAt) < ($1.date, $1.createdAt) }
        }
        if let a = latest(session.ascents), let r = converted(a.gradeRaw, a.gradeSystem) { return r }
        if let a = latest(allSessions.flatMap(\.ascents)), let r = converted(a.gradeRaw, a.gradeSystem) { return r }

        return (target, target.grades.first ?? Ascent.ungraded)
    }
}
