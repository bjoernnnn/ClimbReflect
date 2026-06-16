import Foundation
import Combine
import WatchConnectivity

// W5.1/5.2/5.3: WatchConnectivity bidirektional — Session-Transfer Watch→iPhone, Projekte iPhone→Watch

final class SyncService: NSObject, WCSessionDelegate, ObservableObject {
    static let shared = SyncService()

    @Published var lastTransferStatus: String = ""
    @Published var knownProjects: [String] = []   // W5.2: vom iPhone empfangen

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

    // MARK: - W5.2: Projekte-Update vom iPhone empfangen

    static let projectsKey = "knownProjects"

    func session(_ session: WCSession,
                 didReceiveApplicationContext applicationContext: [String: Any]) {
        if let projects = applicationContext[SyncService.projectsKey] as? [String] {
            DispatchQueue.main.async {
                self.knownProjects = projects
            }
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        if activationState == .activated {
            DispatchQueue.main.async { self.flushPending() }
        }
    }
}
