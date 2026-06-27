import Foundation
import SwiftData

@Model
final class Shoe {
    @Attribute(.unique) var id: UUID
    var name: String
    var startMonth: Int        // 1…12
    var startYear: Int
    var isRetired: Bool = false
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \Ascent.shoe) var ascents: [Ascent] = []

    var startDate: Date {
        Calendar.current.date(from: DateComponents(year: startYear, month: startMonth, day: 1)) ?? createdAt
    }

    init(name: String, startMonth: Int, startYear: Int) {
        self.id = UUID()
        self.name = name
        self.startMonth = startMonth
        self.startYear = startYear
        self.createdAt = .now
    }
}
