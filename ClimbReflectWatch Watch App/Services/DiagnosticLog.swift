import Foundation

// Ring-Puffer für persistente Diagnose-Events (letzte 200 Einträge).
// Zugriff ausschließlich von MainActor.

struct DiagnosticEntry: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let event: String

    init(_ event: String) {
        self.id = UUID()
        self.timestamp = Date()
        self.event = event
    }
}

@MainActor
final class DiagnosticLog: ObservableObject {
    static let shared = DiagnosticLog()

    @Published private(set) var entries: [DiagnosticEntry] = []

    private let maxEntries = 200
    private let fileName = "diagnosticLog.json"
    private var fileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(fileName)
    }

    private init() { load() }

    func log(_ event: String) {
        let entry = DiagnosticEntry(event)
        entries.append(entry)
        if entries.count > maxEntries { entries.removeFirst(entries.count - maxEntries) }
        persist()
    }

    func clear() {
        entries = []
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func persist() {
        try? JSONEncoder().encode(entries).write(to: fileURL, options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let saved = try? JSONDecoder().decode([DiagnosticEntry].self, from: data)
        else { return }
        entries = saved
    }
}
