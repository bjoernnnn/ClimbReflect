import Foundation
import Combine

// Ring-Puffer für persistente Diagnose-Events (letzte 200 Einträge).
// Zugriff ausschließlich von MainActor.
// A6: Disk-Schreibzugriffe gedrosselt (max 1×/10s); flush() für sofortiges Schreiben.

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

    private var pendingPersist: Task<Void, Never>?

    private init() { load() }

    func log(_ event: String, flushImmediately: Bool = false) {
        let entry = DiagnosticEntry(event)
        entries.append(entry)
        if entries.count > maxEntries { entries.removeFirst(entries.count - maxEntries) }
        if flushImmediately { flush() } else { schedulePersist() }
    }

    /// Sofortige Sicherung – aufrufen bei Session-Ende und App-Hintergrund.
    func flush() {
        pendingPersist?.cancel()
        pendingPersist = nil
        persist()
    }

    func clear() {
        entries = []
        pendingPersist?.cancel()
        pendingPersist = nil
        try? FileManager.default.removeItem(at: fileURL)
    }

    // A6: Schreibvorgang debouncen – höchstens 1×/10s
    private func schedulePersist() {
        pendingPersist?.cancel()
        pendingPersist = Task { [weak self] in
            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled, let self else { return }
            self.persist()
            self.pendingPersist = nil
        }
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
