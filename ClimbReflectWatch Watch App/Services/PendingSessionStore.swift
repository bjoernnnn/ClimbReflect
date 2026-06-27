import Foundation

// Persistiert die laufende Session nach jeder Mutation auf Disk.
// Bei App-Neustart nach Absturz werden die Begehungen über SyncService gerettet.
// ProjectInfo wird als flache Strings gespeichert (vermeidet Codable-Konformanz
// auf einem @MainActor-Struct unter SWIFT_DEFAULT_ACTOR_ISOLATION=MainActor).

struct PendingSession: Codable {
    let id: UUID
    let startDate: Date
    let sessionTypeRaw: String
    let projectID: String?
    let projectName: String?
    // SH-7: Schuh-Snapshot (optional → alte Snapshots dekodieren weiter)
    var shoeID: String?
    var shoeName: String?
    let ascents: [WatchSessionDTO.AscentDTO]
    let accumulatedPaused: TimeInterval

    // Optionals → alte Snapshots ohne diese Felder laden ohne Crash
    var maxHeartRate: Double?
    var hrSum: Double?
    var hrCount: Int?
    var activeEnergyKcal: Double?
    var lastHeartRate: Double?

    var projectInfo: ProjectInfo? {
        guard let id = projectID, let name = projectName else { return nil }
        return ProjectInfo(id: id, name: name)
    }

    var shoeInfo: ShoeInfo? {
        guard let id = shoeID, let name = shoeName else { return nil }
        return ShoeInfo(id: id, name: name)
    }
}

enum PendingSessionStore {
    private static let fileName = "pendingSession.json"

    private static var fileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(fileName)
    }

    static func save(_ session: PendingSession) {
        try? JSONEncoder().encode(session).write(to: fileURL, options: .atomic)
    }

    static func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    static func load() -> PendingSession? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(PendingSession.self, from: data)
    }
}
