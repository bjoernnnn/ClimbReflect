import Foundation
import SwiftData

// ERFOLGE-KONZEPT-V2 EP-3: einziger Aufrufpunkt für die Erfolgs-Auswertung.
// checkNow() fetcht Sessions/Projekte/vorhandene Unlocks, lässt die reine
// AchievementEngine rechnen und persistiert nur wirklich neue Unlocks
// (seenByUser = false → Celebration-Queue holt sie ab).

@MainActor
final class AchievementService {
    static let shared = AchievementService()
    private init() {}

    @discardableResult
    func checkNow(context: ModelContext) -> [AchievementUnlock] {
        let sessions = (try? context.fetch(FetchDescriptor<ClimbSession>())) ?? []
        let projects = (try? context.fetch(FetchDescriptor<Project>())) ?? []
        let existingUnlocks = (try? context.fetch(FetchDescriptor<AchievementUnlock>())) ?? []

        var seen = Set(existingUnlocks.map(existingKey))
        let pending = AchievementEngine.evaluate(sessions: sessions, projects: projects, existing: seen)
        guard !pending.isEmpty else { return [] }

        var inserted: [AchievementUnlock] = []
        for p in pending {
            // Defensiv gegen Doppel-Events innerhalb desselben evaluate()-Laufs
            // (sollte die Engine nicht liefern, kostet die Prüfung aber nichts).
            let k = AchievementEngine.ExistingUnlockKey(
                definitionID: p.definitionID, tier: p.tier,
                contextValue: p.tier == nil ? p.contextValue : nil,
                sessionID: p.tier == nil ? p.sessionID : nil)
            guard !seen.contains(k) else { continue }
            seen.insert(k)

            let unlock = AchievementUnlock(definitionID: p.definitionID, tier: p.tier, unlockedAt: p.date,
                                           contextValue: p.contextValue, sessionID: p.sessionID, seenByUser: false)
            context.insert(unlock)
            inserted.append(unlock)
        }
        try? context.save()
        return inserted
    }

    private func existingKey(_ u: AchievementUnlock) -> AchievementEngine.ExistingUnlockKey {
        .init(definitionID: u.definitionID, tier: u.tier,
             contextValue: u.tier == nil ? u.contextValue : nil,
             sessionID: u.tier == nil ? u.sessionID : nil)
    }
}
