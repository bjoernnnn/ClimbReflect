import Foundation
import Combine
import WatchConnectivity

// W5.1/5.2/5.3: WatchConnectivity bidirektional — Session-Transfer Watch→iPhone, Projekte iPhone→Watch

struct ProjectInfo: Identifiable, Hashable {
    let id: String   // UUID-String
    let name: String
}

// SH-6: Schuh-Info für Watch-Selektor (analog ProjectInfo)
struct ShoeInfo: Identifiable, Hashable {
    let id: String   // UUID-String
    let name: String
    let condition: String?       // ShoeCondition.rawValue, Snapshot zum Zeitpunkt des Empfangs
    let defaultForTypes: [String]   // SH-12: SessionType.rawValues, für Auto-Vorauswahl
}

final class SyncService: NSObject, WCSessionDelegate, ObservableObject {
    static let shared = SyncService()

    @Published var lastTransferStatus: String = ""
    @Published var knownProjects: [ProjectInfo] = []   // W5.2: vom iPhone empfangen
    @Published var knownShoes: [ShoeInfo] = []          // SH-6: vom iPhone empfangen

    // W5.3: Lokale Queue für Transfers die offline gehen
    private var pendingDTOs: [WatchSessionDTO] = []
    private let pendingKey = "pendingWatchDTOs"

    override init() {
        super.init()
        loadPending()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    // MARK: - W5.1: Session senden (mit Offline-Fallback)

    func send(dto: WatchSessionDTO) {
        do {
            let data = try JSONEncoder().encode(dto)
            let payload: [String: Any] = [WatchSessionDTO.transferKey: data]
            // transferUserInfo ist zuverlässig auch im Hintergrund (W5.3)
            WCSession.default.transferUserInfo(payload)
            lastTransferStatus = "Übertragen"
            flushPending()
        } catch {
            pendingDTOs.append(dto)
            savePending()
            lastTransferStatus = "Gespeichert – wird gesendet sobald iPhone erreichbar"
        }
    }

    // Diagnose-Log ans iPhone übertragen (transferUserInfo → zuverlässig auch im Hintergrund)
    func sendDiagnostics(_ entries: [DiagnosticEntry]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        WCSession.default.transferUserInfo(["diagnosticLog": data])
    }

    // W5.3: Pending-Queue absenden wenn Verbindung wieder da
    private func flushPending() {
        guard !pendingDTOs.isEmpty else { return }
        let toSend = pendingDTOs
        pendingDTOs.removeAll()
        savePending()
        toSend.forEach { send(dto: $0) }
    }

    // MARK: - Persistierung der Pending-Queue (W5.3)

    private func savePending() {
        if let data = try? JSONEncoder().encode(pendingDTOs) {
            UserDefaults.standard.set(data, forKey: pendingKey)
        }
    }

    private func loadPending() {
        guard let data = UserDefaults.standard.data(forKey: pendingKey),
              let dtos = try? JSONDecoder().decode([WatchSessionDTO].self, from: data)
        else { return }
        pendingDTOs = dtos
    }

    // E2: Befehle vom iPhone empfangen (Pause/Resume/End)
    var onCommand: ((String) -> Void)?

    // MARK: - W5.2: Projekte-Update vom iPhone empfangen

    static let projectsKey = "knownProjects"
    static let projectListKey = "projectList"
    static let shoeListKey = "shoeList"

    func session(_ session: WCSession,
                 didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async { self.applyContext(applicationContext) }
    }

    private func applyContext(_ context: [String: Any]) {
        // Projekte
        if let list = context[SyncService.projectListKey] as? [[String: String]] {
            knownProjects = list.compactMap { dict -> ProjectInfo? in
                guard let id = dict["id"], let name = dict["name"] else { return nil }
                return ProjectInfo(id: id, name: name)
            }
        } else if let names = context[SyncService.projectsKey] as? [String] {
            knownProjects = names.map { ProjectInfo(id: $0, name: $0) }
        }
        // SH-6/SH-12: Schuhe inkl. Standard-Zuordnung
        if let list = context[SyncService.shoeListKey] as? [[String: Any]] {
            knownShoes = list.compactMap { dict -> ShoeInfo? in
                guard let id = dict["id"] as? String, let name = dict["name"] as? String else { return nil }
                return ShoeInfo(
                    id: id,
                    name: name,
                    condition: dict["condition"] as? String,
                    defaultForTypes: dict["defaultForTypes"] as? [String] ?? []
                )
            }
        }
    }

    func session(_ session: WCSession,
                 didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        if let command = message["watchCommand"] as? String {
            DispatchQueue.main.async { self.onCommand?(command) }
        }
        replyHandler([:])
    }

    // F3: Fallback für transferUserInfo-Befehle (Watch-App im Hintergrund)
    func session(_ session: WCSession,
                 didReceiveUserInfo userInfo: [String: Any] = [:]) {
        if let command = userInfo["watchCommand"] as? String {
            DispatchQueue.main.async { self.onCommand?(command) }
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        if activationState == .activated {
            DispatchQueue.main.async {
                self.flushPending()
                self.applyContext(session.receivedApplicationContext)
            }
        }
    }
}
