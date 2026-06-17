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

    private var modelContext: ModelContext?

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    // W5.2: Aktive+angepinnte Projekte an Watch pushen
    func pushProjectsToWatch(modelContext: ModelContext) {
        guard WCSession.default.activationState == .activated,
              WCSession.default.isWatchAppInstalled else { return }
        let projects = (try? modelContext.fetch(FetchDescriptor<Project>())) ?? []
        let active = projects.filter { $0.isActive }
        let list: [[String: String]] = active.map { ["id": $0.id.uuidString, "name": $0.name] }
        let names: [String] = active.map(\.name)
        let context: [String: Any] = [
            "projectList": list,
            Self.projectsKey: names
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

    // MARK: - Persistierung

    private func insert(dto: WatchSessionDTO) {
        guard let ctx = modelContext else { return }

        // B2: Wenn eine healthKit-Dublette mit gleicher workoutUUID existiert,
        // diese löschen – die reichhaltigere Watch-Version (mit Begehungen) gewinnt.
        if let wid = dto.workoutUUID,
           let existing = try? ctx.fetch(FetchDescriptor<ClimbSession>())
               .first(where: { $0.workoutUUID == wid && $0.source == .healthKit }) {
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

        climbSession.altitudeTotalGain = dto.altitudeTotalGain

        // RPE aus dem Fragebogen
        if let rpe = dto.rpe { climbSession.perceivedEffort = rpe }

        // Training: focusRaw = Limiter rawValue (Zielkapazität)
        if sessionType == .training, let f = dto.focusRaw, let limiter = Limiter(rawValue: f) {
            climbSession.limiterRaw = [limiter.rawValue]
        }

        ctx.insert(climbSession)

        let allProjects = (try? ctx.fetch(FetchDescriptor<Project>())) ?? []

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

            // Projekt-Relation aufbauen (ID bevorzugt, dann Name als Fallback)
            if let pid = ascentDTO.projectID,
               let project = allProjects.first(where: { $0.id == pid }) {
                ascent.project = project
            } else if let name = ascentDTO.projectName {
                if let project = allProjects.first(where: {
                    $0.name.lowercased() == name.lowercased()
                }) {
                    ascent.project = project
                } else {
                    let project = Project(name: name)
                    ctx.insert(project)
                    ascent.project = project
                }
            }

            ctx.insert(ascent)
        }

        try? ctx.save()
    }
}
