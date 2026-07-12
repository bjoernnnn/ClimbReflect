import Foundation
import SwiftData
import UIKit

// ERFOLGE-KONZEPT-V2 EP-3: einziger Aufrufpunkt für die Erfolgs-Auswertung.
// checkNow() fetcht Sessions/Projekte/vorhandene Unlocks, lässt die reine
// AchievementEngine rechnen und persistiert nur wirklich neue Unlocks
// (seenByUser = false → Celebration-Queue holt sie ab).

@MainActor
final class AchievementService {
    static let shared = AchievementService()
    private init() {}

    @discardableResult
    func checkNow(context: ModelContext, notify: Bool = true) -> [AchievementUnlock] {
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
        if notify { notifyIfBackground(inserted) }
        return inserted
    }

    private func existingKey(_ u: AchievementUnlock) -> AchievementEngine.ExistingUnlockKey {
        .init(definitionID: u.definitionID, tier: u.tier,
             contextValue: u.tier == nil ? u.contextValue : nil,
             sessionID: u.tier == nil ? u.sessionID : nil)
    }

    // MARK: - EP-11: Benachrichtigung bei Hintergrund-Unlock

    /// Watch-DTO kann eintreffen, während die App im Hintergrund ist — der
    /// Moment darf nicht verpuffen. Im Vordergrund übernimmt ausschließlich
    /// das Overlay (nie beides); nur .full-Erfolge benachrichtigen (.quiet
    /// bleibt bewusst leise, auch im Hintergrund).
    private func notifyIfBackground(_ unlocks: [AchievementUnlock]) {
        guard UIApplication.shared.applicationState != .active else { return }
        for unlock in unlocks {
            guard let def = AchievementDefinition.definition(id: unlock.definitionID),
                  def.celebration == .full else { continue }
            NotificationService.shared.notifyUnlock(title: def.title, subtitle: notificationSubtitle(unlock, def))
        }
    }

    private func notificationSubtitle(_ unlock: AchievementUnlock, _ def: AchievementDefinition) -> String {
        if case .tiered(let tiers) = def.kind, let t = unlock.tier, tiers.indices.contains(t),
           let name = tiers[t].name {
            return name
        }
        return unlock.contextValue ?? ""
    }

    // MARK: - EP-4: Backfill (Endowed Progress, L2)

    private static let backfillFlagKey = "achievementsBackfilledV2"

    /// Beim ersten Start nach dem Update: historische Erfolge rückwirkend mit
    /// korrektem damaligem Datum freischalten, aber sofort als gesehen markieren
    /// (seenByUser = true) — keine Celebration-Flut über Altdaten (L7).
    func backfillIfNeeded(context: ModelContext) {
        let ud = UserDefaults.standard
        guard !ud.bool(forKey: Self.backfillFlagKey) else { return }

        let unlocks = checkNow(context: context, notify: false)
        for u in unlocks { u.seenByUser = true }
        try? context.save()

        #if DEBUG
        if !unlocks.isEmpty {
            print("[Achievements] Backfill: \(unlocks.count) Unlocks")
            for u in unlocks.sorted(by: { $0.unlockedAt < $1.unlockedAt }) {
                let tierText = u.tier.map { "tier=\($0) " } ?? ""
                let ctxText = u.contextValue.map { "context=\($0) " } ?? ""
                print("  \(u.unlockedAt) · \(u.definitionID) \(tierText)\(ctxText)")
            }
        }
        #endif

        ud.set(true, forKey: Self.backfillFlagKey)
    }
}
