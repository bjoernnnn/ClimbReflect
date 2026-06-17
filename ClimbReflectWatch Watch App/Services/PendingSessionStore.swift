import Foundation

// Persistiert die laufende Session nach jeder Mutation auf Disk.
// Bei App-Neustart nach Absturz werden die Begehungen über SyncService gerettet.

struct PendingSession: Codable {
    let id: UUID
    let startDate: Date
    let sessionTypeRaw: String
    let projectInfo: ProjectInfo?
    let ascents: [WatchSessionDTO.AscentDTO]
    let accumulatedPaused: TimeInterval
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
