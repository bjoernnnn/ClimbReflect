import Foundation
import SwiftData

enum ShoeCondition: String, Codable, CaseIterable, Identifiable {
    case neu         = "Neu"
    case eingetragen = "Eingetragen"
    case benutzt     = "Benutzt"
    case resoled     = "Resoled"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .neu:         return "sparkles"
        case .eingetragen: return "checkmark.seal.fill"
        case .benutzt:     return "clock.arrow.circlepath"
        case .resoled:     return "arrow.2.circlepath"
        }
    }
}

@Model
final class Shoe {
    // CK-P0: .unique entfernt + Defaults ergänzt (CloudKit-Voraussetzungen).
    // startMonth/startYear-Defaults sind reine Schema-Platzhalter – der App-Init
    // verlangt echte Werte, sie werden hier nie faktisch verwendet.
    var id: UUID = UUID()
    var name: String = ""
    var startMonth: Int = 1        // 1…12
    var startYear: Int = 2000
    var isRetired: Bool = false
    var conditionRaw: String = ShoeCondition.neu.rawValue
    var isBuiltInDefault: Bool = false      // SH-A: nicht löschbar, immer einer vorhanden
    var defaultForTypesRaw: [String] = []   // SH-B: SessionType.rawValues für Auto-Vorauswahl
    var createdAt: Date = Date.now

    @Relationship(deleteRule: .nullify, inverse: \Ascent.shoe) var ascents: [Ascent] = []

    var condition: ShoeCondition {
        get { ShoeCondition(rawValue: conditionRaw) ?? .neu }
        set { conditionRaw = newValue.rawValue }
    }

    var defaultForTypes: [SessionType] {
        defaultForTypesRaw.compactMap(SessionType.init(rawValue:))
    }

    var startDate: Date {
        Calendar.current.date(from: DateComponents(year: startYear, month: startMonth, day: 1)) ?? createdAt
    }

    init(name: String, startMonth: Int, startYear: Int) {
        self.id = UUID()
        self.name = name
        self.startMonth = startMonth
        self.startYear = startYear
        self.conditionRaw = ShoeCondition.neu.rawValue
        self.createdAt = .now
    }
}
