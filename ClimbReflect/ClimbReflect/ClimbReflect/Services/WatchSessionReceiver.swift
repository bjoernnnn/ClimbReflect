import Foundation
import Combine
import SwiftData
import WatchConnectivity

// W5.1/5.2/5.3: Empfängt WatchSessionDTO und sendet Projekte-Liste an Watch

@MainActor
final class WatchSessionReceiver: NSObject, WCSessionDelegate, ObservableObject {
    static let shared = WatchSessionReceiver()
    static let projectsKey = "knownProjects"

    @Published var liveStatus: WatchLiveStatus?
    @Published var diagnosticLogText: String = ""
    @Published var diagnosticLogFileURL: URL?

    private var modelContext: ModelContext?

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    // W5.2: Aktive+angepinnte Projekte + Schuhe an Watch pushen
    func pushProjectsToWatch(modelContext: ModelContext) {
        guard WCSession.default.activationState == .activated,
              WCSession.default.isWatchAppInstalled else { return }
        let projects = (try? modelContext.fetch(FetchDescriptor<Project>())) ?? []
        let active = projects.filter { $0.isActive }
        let projectList: [[String: String]] = active.map { ["id": $0.id.uuidString, "name": $0.name] }
        let projectNames: [String] = active.map(\.name)

        // SH-6: Aktive (nicht retired) Schuhe mitsenden
        let shoes = (try? modelContext.fetch(FetchDescriptor<Shoe>())) ?? []
        let activeShoes = shoes.filter { !$0.isRetired }
        let shoeList: [[String: String]] = activeShoes.map { ["id": $0.id.uuidString, "name": $0.name] }

        let context: [String: Any] = [
            "projectList": projectList,
            Self.projectsKey: projectNames,
            "shoeList": shoeList
        ]
        try? WCSession.default.updateApplicationContext(context)
    }

    func pushProjectsToWatch() {
        guard let ctx = modelContext else { return }
        pushProjectsToWatch(modelContext: ctx)
    }

    // MARK: - WCSessionDelegate

    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {
        Task { @MainActor [self] in
            self.readLiveStatusFromContext(session.receivedApplicationContext)
            if activationState == .activated {
                self.pushProjectsToWatch()
            }
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    nonisolated func session(_ session: WCSession,
                             didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor [self] in
            self.readLiveStatusFromContext(applicationContext)
        }
    }

    // E1: Live-Status aus applicationContext dekodieren
    private func readLiveStatusFromContext(_ context: [String: Any]) {
        guard let raw = context[WatchLiveStatus.key] else { return }  // key absent → ignore
        if let data = raw as? Data, !data.isEmpty,
           let status = try? JSONDecoder().decode(WatchLiveStatus.self, from: data) {
            liveStatus = status
        } else {
            liveStatus = nil  // empty Data → session ended
        }
        LiveActivityController.shared.update(with: liveStatus)
    }

    // E2: Befehle von iPhone an Watch weiterleiten (Pause/Resume/End)
    nonisolated func session(_ session: WCSession,
                             didReceiveMessage message: [String: Any],
                             replyHandler: @escaping ([String: Any]) -> Void) {
        replyHandler([:])
    }

    nonisolated func session(_ session: WCSession,
                             didReceiveUserInfo userInfo: [String: Any] = [:]) {
        if let diagData = userInfo["diagnosticLog"] as? Data {
            Task { @MainActor [self] in self.storeDiagnostics(diagData) }
            return
        }
        // Literal statt WatchSessionDTO.transferKey — nonisolated Kontext darf keine
        // @MainActor-isolierten statischen Properties lesen (SWIFT_DEFAULT_ACTOR_ISOLATION).
        guard let data = userInfo["watchSessionDTO"] as? Data else { return }
        Task { @MainActor [self] in
            guard let dto = try? JSONDecoder().decode(WatchSessionDTO.self, from: data)
            else { return }
            self.insert(dto: dto)
            // Session beendet → Live-Status löschen
            self.liveStatus = nil
            LiveActivityController.shared.update(with: nil)
        }
    }

    @MainActor
    private func storeDiagnostics(_ data: Data) {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("watchDiagnostics.json")
        try? data.write(to: url, options: .atomic)
        diagnosticLogFileURL = url

        struct Entry: Decodable { let timestamp: Date; let event: String }
        guard let entries = try? JSONDecoder().decode([Entry].self, from: data) else { return }
        let df = DateFormatter()
        df.dateFormat = "HH:mm:ss"
        diagnosticLogText = entries
            .map { "\(df.string(from: $0.timestamp))  \($0.event)" }
            .joined(separator: "\n")
    }

    // MARK: - Persistierung

    private func insert(dto: WatchSessionDTO) {
        guard let ctx = modelContext else { return }

        let allSessions = (try? ctx.fetch(FetchDescriptor<ClimbSession>())) ?? []

        // P1-5: Upsert via watchSessionID – verhindert Duplikate bei Doppel-Zustellung
        if let existing = allSessions.first(where: { $0.watchSessionID == dto.id }) {
            // Nur Anreicherungsfelder aktualisieren (RPE, Focus) – Ascents bleiben
            if let rpe = dto.rpe { existing.perceivedEffort = rpe }
            if let f = dto.focusRaw, let limiter = Limiter(rawValue: f) {
                existing.limiterRaw = [limiter.rawValue]
            }
            try? ctx.save()
            return
        }

        // B2: Wenn eine healthKit-Dublette mit gleicher workoutUUID existiert,
        // diese löschen – die reichhaltigere Watch-Version (mit Begehungen) gewinnt.
        if let wid = dto.workoutUUID,
           let existing = allSessions.first(where: { $0.workoutUUID == wid && $0.source == .healthKit }) {
            ctx.delete(existing)
        }

        let sessionType = SessionType(rawValue: dto.sessionTypeRaw) ?? .boulder
        let climbSession = ClimbSession(
            workoutUUID: dto.workoutUUID,
            date: dto.date,
            durationSeconds: dto.durationSeconds,
            sessionType: sessionType,
            source: .watch,
            avgHeartRate: dto.avgHeartRate,
            maxHeartRate: dto.maxHeartRate,
            activeEnergyKcal: dto.activeEnergyKcal
        )

        climbSession.watchSessionID = dto.id
        climbSession.altitudeTotalGain = dto.altitudeTotalGain

        // RPE aus dem Fragebogen
        if let rpe = dto.rpe { climbSession.perceivedEffort = rpe }

        // Training: focusRaw = Limiter rawValue (Zielkapazität)
        if sessionType == .training, let f = dto.focusRaw, let limiter = Limiter(rawValue: f) {
            climbSession.limiterRaw = [limiter.rawValue]
        }

        ctx.insert(climbSession)

        let allProjects = (try? ctx.fetch(FetchDescriptor<Project>())) ?? []
        let allShoes = (try? ctx.fetch(FetchDescriptor<Shoe>())) ?? []   // SH-9

        for ascentDTO in dto.ascents {
            let ascent = Ascent(
                gradeSystem: GradeSystem(rawValue: ascentDTO.gradeSystemRaw) ?? .fontainebleau,
                grade: ascentDTO.gradeRaw ?? "?",
                result: AscentResult(rawValue: ascentDTO.resultRaw ?? "") ?? .attempt,
                style: ascentDTO.styleRaw.flatMap(AscentStyle.init(rawValue:)),
                attempts: ascentDTO.attempts,
                date: ascentDTO.date,
                projectName: ascentDTO.projectName,
                session: climbSession
            )
            ascent.altitudeGain = ascentDTO.altitudeGain
            ascent.durationSeconds = ascentDTO.durationSeconds

            // P2-7: Projekt-Relation aufbauen
            // ID vorhanden → nur per ID matchen, nie neu anlegen (iPhone ist Source of Truth)
            // Nur Name → case-insensitive + trimmed matchen; neu anlegen nur ohne ID
            if let pid = ascentDTO.projectID {
                ascent.project = allProjects.first(where: { $0.id == pid })
            } else if let name = ascentDTO.projectName {
                let trimmed = name.trimmingCharacters(in: .whitespaces).lowercased()
                if let project = allProjects.first(where: {
                    $0.name.trimmingCharacters(in: .whitespaces).lowercased() == trimmed
                }) {
                    ascent.project = project
                } else {
                    let project = Project(name: name.trimmingCharacters(in: .whitespaces))
                    ctx.insert(project)
                    ascent.project = project
                }
            }

            // SH-9: Schuh-Relation aufbauen — kein Auto-Anlegen (iPhone ist Source of Truth)
            ascent.shoeName = ascentDTO.shoeName
            if let sid = ascentDTO.shoeID {
                ascent.shoe = allShoes.first(where: { $0.id == sid })
            } else if let name = ascentDTO.shoeName {
                let trimmed = name.trimmingCharacters(in: .whitespaces).lowercased()
                ascent.shoe = allShoes.first(where: {
                    $0.name.trimmingCharacters(in: .whitespaces).lowercased() == trimmed
                })
                // Bei unbekanntem Namen: shoe bleibt nil, shoeName-Cache erhalten
            }

            ctx.insert(ascent)
        }

        try? ctx.save()
    }
}
