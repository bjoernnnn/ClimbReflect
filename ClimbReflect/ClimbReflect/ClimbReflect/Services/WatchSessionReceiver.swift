import Foundation
import Combine
import SwiftData
import WatchConnectivity

// W5.1/5.2/5.3: Empfängt WatchSessionDTO und sendet Projekte-Liste an Watch

@MainActor
final class WatchSessionReceiver: NSObject, WCSessionDelegate, ObservableObject {
    static let shared = WatchSessionReceiver()
    static let projectsKey = "knownProjects"

    private var modelContext: ModelContext?

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    // W5.2: Aktuelle Projekte an Watch pushen (aufrufen wenn Projekte sich ändern)
    func pushProjectsToWatch(_ sessions: [ClimbSession]) {
        guard WCSession.default.activationState == .activated,
              WCSession.default.isWatchAppInstalled else { return }
        let projectNames = Array(Set(sessions
            .flatMap(\.ascents)
            .compactMap(\.projectName)))
            .sorted()
        let context: [String: Any] = [Self.projectsKey: projectNames]
        try? WCSession.default.updateApplicationContext(context)
    }

    // MARK: - WCSessionDelegate

    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {}

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    nonisolated func session(_ session: WCSession,
                             didReceiveUserInfo userInfo: [String: Any] = [:]) {
        // Data ist Sendable → sicher aus nonisolated-Kontext an @MainActor übergeben
        guard let data = userInfo["watchSessionDTO"] as? Data else { return }
        Task { @MainActor [self] in
            guard let dto = try? JSONDecoder().decode(WatchSessionDTO.self, from: data)
            else { return }
            self.insert(dto: dto)
        }
    }

    // MARK: - Persistierung

    private func insert(dto: WatchSessionDTO) {
        guard let ctx = modelContext else { return }

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

        ctx.insert(climbSession)

        for ascentDTO in dto.ascents {
            let ascent = Ascent(
                gradeSystem: GradeSystem(rawValue: ascentDTO.gradeSystemRaw) ?? .fontainebleau,
                grade: ascentDTO.gradeRaw ?? "?",
                result: AscentResult(rawValue: ascentDTO.resultRaw ?? "") ?? .attempt,
                style: ascentDTO.styleRaw.flatMap(AscentStyle.init(rawValue:)),
                attempts: ascentDTO.attempts,
                date: ascentDTO.date,
                session: climbSession
            )
            ctx.insert(ascent)
        }

        try? ctx.save()
    }
}
