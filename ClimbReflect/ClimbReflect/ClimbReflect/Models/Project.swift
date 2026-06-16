import Foundation
import SwiftData

// B1: Projekt-Entität — ergänzt die aus Ascent.projectName abgeleiteten Daten
// um persönliche Notizen und einen optionalen Status-Override.

@Model
final class Project {
    @Attribute(.unique) var id: UUID
    var name: String               // entspricht Ascent.projectName
    var betaNotes: String = ""     // sessionübergreifende Beta-Notizen
    var statusRaw: String?         // nil = auto-abgeleitet; "abandoned" = manuell aufgegeben
    var createdAt: Date

    enum Status: String {
        case active, sent, abandoned
    }

    init(name: String, betaNotes: String = "", statusRaw: String? = nil) {
        self.id = UUID()
        self.name = name
        self.betaNotes = betaNotes
        self.statusRaw = statusRaw
        self.createdAt = .now
    }
}
