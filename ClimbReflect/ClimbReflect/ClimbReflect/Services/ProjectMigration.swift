import Foundation
import SwiftData

@MainActor
enum ProjectMigration {
    private static let doneKey = "projectMigrationV1Done"

    static func runIfNeeded(context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: doneKey) else { return }

        let ascents = (try? context.fetch(FetchDescriptor<Ascent>())) ?? []
        let existingProjects = (try? context.fetch(FetchDescriptor<Project>())) ?? []

        var projectsByName: [String: Project] = Dictionary(
            uniqueKeysWithValues: existingProjects.map { ($0.name.lowercased(), $0) }
        )

        for ascent in ascents {
            guard let raw = ascent.projectName, !raw.isEmpty else { continue }
            guard ascent.project == nil else { continue }

            let key = raw.trimmingCharacters(in: .whitespaces).lowercased()
            if let existing = projectsByName[key] {
                ascent.project = existing
            } else {
                let trimmed = raw.trimmingCharacters(in: .whitespaces)
                let project = Project(name: trimmed)
                context.insert(project)
                projectsByName[key] = project
                ascent.project = project
            }
        }

        try? context.save()
        UserDefaults.standard.set(true, forKey: doneKey)
    }
}
