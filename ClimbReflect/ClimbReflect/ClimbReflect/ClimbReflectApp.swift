import SwiftUI
import SwiftData
import ActivityKit

@main
struct ClimbReflectApp: App {
    let container: ModelContainer

    init() {
        let schema = Schema([ClimbSession.self, Ascent.self, Project.self, ProjectMedia.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            // Schema-Migration fehlgeschlagen → Store löschen und neu erstellen
            // (tritt nur nach Breaking-Schema-Änderungen auf, Daten gehen verloren)
            let storeURL = config.url
            try? FileManager.default.removeItem(at: storeURL)
            let walURL = storeURL.deletingPathExtension().appendingPathExtension("sqlite-wal")
            let shmURL = storeURL.deletingPathExtension().appendingPathExtension("sqlite-shm")
            try? FileManager.default.removeItem(at: walURL)
            try? FileManager.default.removeItem(at: shmURL)
            do {
                container = try ModelContainer(for: schema, configurations: config)
            } catch {
                fatalError("SwiftData-Container konnte auch nach Reset nicht erstellt werden: \(error)")
            }
        }

        WatchSessionReceiver.shared.configure(modelContext: container.mainContext)
        ProjectMigration.runIfNeeded(context: container.mainContext)
        WatchSessionReceiver.shared.pushProjectsToWatch(modelContext: container.mainContext)
        endOrphanedLiveActivities()
        #if DEBUG
        MockData.seedIfNeeded(container.mainContext)
        #endif
    }

    private func endOrphanedLiveActivities() {
        for activity in Activity<ClimbActivityAttributes>.activities {
            Task { await activity.end(dismissalPolicy: .immediate) }
        }
    }

    var body: some Scene {
        WindowGroup {
            DashboardView()
        }
        .modelContainer(container)
    }
}
