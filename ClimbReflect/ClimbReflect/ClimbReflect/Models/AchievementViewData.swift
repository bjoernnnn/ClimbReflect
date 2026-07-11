import Foundation

// ERFOLGE-KONZEPT-V2 EP-6: View-taugliche Aufbereitung eines Katalog-Eintrags
// gegen die persistierten Unlocks + Live-Fortschritt. Einmal pro Render aus
// @Query-Daten gebaut, von AchievementsView und NextAchievementsCard geteilt.

struct AchievementViewData: Identifiable {
    let definition: AchievementDefinition
    let isUnlocked: Bool
    let material: AchievementMaterial?     // nil solange gesperrt
    let unlockedDate: Date?                // jüngstes Ereignis (once/tiered: das eine; repeatable: das letzte)
    let count: Int                         // Anzahl Ereignisse (repeatable: „×N")
    let currentTierIndex: Int?             // höchste erreichte Stufe (tiered)
    let progress: AchievementEngine.AchievementProgress?
    let events: [AchievementUnlock]        // chronologisch aufsteigend

    var id: String { definition.id }
}

enum AchievementViewModel {
    static func build(sessions: [ClimbSession], projects: [Project],
                      unlocks: [AchievementUnlock]) -> [AchievementViewData] {
        let byDefinition = Dictionary(grouping: unlocks, by: \.definitionID)
        return AchievementDefinition.all.map { def in
            let events = (byDefinition[def.id] ?? []).sorted { $0.unlockedAt < $1.unlockedAt }
            let isUnlocked = !events.isEmpty
            var material: AchievementMaterial?
            var currentTierIndex: Int?

            switch def.kind {
            case .once(let m), .repeatable(let m):
                material = isUnlocked ? m : nil
            case .tiered(let tiers):
                if let maxTier = events.compactMap(\.tier).max() {
                    currentTierIndex = maxTier
                    material = tiers[maxTier].material
                }
            }

            // Verborgene, noch nicht enthüllte Erfolge zeigen nie einen Fortschritt
            // (würde den geheimen Charakter verraten, L6).
            let progress = (def.isHidden && !isUnlocked) ? nil
                : AchievementEngine.progress(for: def.id, sessions: sessions, projects: projects)

            return AchievementViewData(definition: def, isUnlocked: isUnlocked, material: material,
                                       unlockedDate: events.last?.unlockedAt, count: events.count,
                                       currentTierIndex: currentTierIndex, progress: progress, events: events)
        }
    }
}
