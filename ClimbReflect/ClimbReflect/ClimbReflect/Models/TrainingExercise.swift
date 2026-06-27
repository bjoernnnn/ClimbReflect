import Foundation
import SwiftData

enum TrainingKind: String, Codable, CaseIterable, Identifiable {
    case hangboardMaxHang = "Maximalhang"
    case repeaters        = "Repeaters"
    case pullUps          = "Klimmzüge"
    case core             = "Core"
    case campus           = "Campus"
    case other            = "Sonstiges"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .hangboardMaxHang: return "hand.raised.fill"
        case .repeaters:        return "repeat"
        case .pullUps:          return "figure.strengthtraining.traditional"
        case .core:             return "rectangle.compress.vertical"
        case .campus:           return "ladder"
        case .other:            return "ellipsis.circle"
        }
    }

    var hasEdge: Bool    { self == .hangboardMaxHang || self == .repeaters }
    var hasWeight: Bool  { self == .hangboardMaxHang || self == .repeaters || self == .pullUps }
    var hasReps: Bool    { self == .pullUps || self == .core || self == .campus }
    var hasDuration: Bool { self == .hangboardMaxHang || self == .repeaters || self == .core }
}

@Model
final class TrainingSet {
    @Attribute(.unique) var id: UUID
    var kindRaw: String
    var edgeMM: Int?
    var addedWeightKg: Double?
    var reps: Int?
    var durationSeconds: Double?
    var sets: Int?
    var note: String?
    var order: Int
    var date: Date

    var session: ClimbSession?

    var kind: TrainingKind {
        TrainingKind(rawValue: kindRaw) ?? .other
    }

    init(kind: TrainingKind, order: Int, date: Date) {
        self.id = UUID()
        self.kindRaw = kind.rawValue
        self.order = order
        self.date = date
    }
}
