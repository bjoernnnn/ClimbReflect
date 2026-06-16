import SwiftUI
import SwiftData

@main
struct ClimbReflectApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: ClimbSession.self, Ascent.self)
        } catch {
            fatalError("SwiftData-Container konnte nicht erstellt werden: \(error)")
        }
        #if DEBUG
        MockData.seedIfNeeded(container.mainContext)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            DashboardView()
        }
        .modelContainer(container)
    }
}
