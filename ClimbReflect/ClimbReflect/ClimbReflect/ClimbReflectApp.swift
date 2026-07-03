import SwiftUI
import SwiftData
import ActivityKit

@main
struct ClimbReflectApp: App {
    let container: ModelContainer

    init() {
        let config = ModelConfiguration(isStoredInMemoryOnly: false)

        do {
            container = try ModelContainer(
                for: ClimbSession.self, Ascent.self, Project.self, ProjectMedia.self,
                configurations: config
            )
        } catch {
            #if DEBUG
            // Im Debug-Build: Store löschen und neu anlegen (schnelle Iteration)
            let storeURL = config.url
            try? FileManager.default.removeItem(at: storeURL)
            let walURL = storeURL.deletingPathExtension().appendingPathExtension("sqlite-wal")
            let shmURL = storeURL.deletingPathExtension().appendingPathExtension("sqlite-shm")
            try? FileManager.default.removeItem(at: walURL)
            try? FileManager.default.removeItem(at: shmURL)
            do {
                container = try ModelContainer(
                    for: ClimbSession.self, Ascent.self, Project.self, ProjectMedia.self,
                    configurations: config
                )
            } catch {
                fatalError("SwiftData-Container konnte auch nach Reset nicht erstellt werden: \(error)")
            }
            #else
            // Im Release-Build: Daten NIEMALS ohne Sicherung löschen
            let ts = Int(Date().timeIntervalSince1970)
            let backup = config.url.deletingPathExtension()
                .appendingPathExtension("backup-\(ts).sqlite")
            try? FileManager.default.copyItem(at: config.url, to: backup)
            fatalError("SwiftData-Migration fehlgeschlagen – Store gesichert als \(backup.lastPathComponent). Bitte App neu installieren oder Support kontaktieren.")
            #endif
        }

        WatchSessionReceiver.shared.configure(modelContext: container.mainContext)
        ProjectMigration.runIfNeeded(context: container.mainContext)
        endOrphanedLiveActivities()
        #if DEBUG
        MockData.seedIfNeeded(container.mainContext)
        #endif
    }

    private func endOrphanedLiveActivities() {
        for activity in Activity<ClimbActivityAttributes>.activities {
            Task { await activity.end(nil as ActivityContent<ClimbActivityAttributes.ContentState>?, dismissalPolicy: .immediate) }
        }
    }

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            DashboardView()
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                LiveActivityController.shared.retryIfNeeded()
            }
        }
    }
}
