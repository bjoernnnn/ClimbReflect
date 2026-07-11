import Foundation
import SwiftData

// ERFOLGE-KONZEPT-V2: persistiertes Unlock-Ereignis. Ein Unlock ist ein
// historisches Ereignis (Widerrufs-Politik: einmal freigeschaltet bleibt
// freigeschaltet, auch wenn die auslösenden Daten später gelöscht werden).

@Model
final class AchievementUnlock {
    // CK-P0: .unique entfernt + Defaults ergänzt (CloudKit-Voraussetzungen).
    var id: UUID = UUID()
    var definitionID: String = ""
    var tier: Int?
    var unlockedAt: Date = Date.now
    var contextValue: String?
    var sessionID: UUID?
    var seenByUser: Bool = false

    init(id: UUID = UUID(), definitionID: String, tier: Int? = nil, unlockedAt: Date,
         contextValue: String? = nil, sessionID: UUID? = nil, seenByUser: Bool = false) {
        self.id = id
        self.definitionID = definitionID
        self.tier = tier
        self.unlockedAt = unlockedAt
        self.contextValue = contextValue
        self.sessionID = sessionID
        self.seenByUser = seenByUser
    }
}
