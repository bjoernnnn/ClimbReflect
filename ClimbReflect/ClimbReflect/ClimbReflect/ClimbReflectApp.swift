import SwiftUI
import SwiftData

@main
struct ClimbReflectApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: ClimbSession.self)
        } catch {
            fatalError("SwiftData-Container konnte nicht erstellt werden: \(error)")
        }
        // Beim ersten Start mit Mock-Daten befüllen.
        MockData.seedIfNeeded(container.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            DashboardView()
        }
        .modelContainer(container)
    }
}
