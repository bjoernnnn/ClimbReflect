import SwiftUI

// MARK: - Aufzählungen

enum SessionType: String, Codable, CaseIterable, Identifiable {
    case boulder, lead, topRope, autoBelay, training, unknown
    var id: String { rawValue }

    var label: String {
        switch self {
        case .boulder:   "Bouldern"
        case .lead:      "Vorstieg"
        case .topRope:   "Toprope"
        case .autoBelay: "Autobelay"
        case .training:  "Training"
        case .unknown:   "Unbekannt"
        }
    }

    var symbol: String {
        switch self {
        case .boulder:   "figure.climbing"
        case .lead:      "arrow.up.right"
        case .topRope:   "arrow.up"
        case .autoBelay: "arrow.up.to.line"
        case .training:  "dumbbell.fill"
        case .unknown:   "questionmark"
        }
    }
}

enum SessionSource: String, Codable {
    case healthKit   // von Redpoint über Apple Health
    case manual
}

enum Limiter: String, Codable, CaseIterable, Identifiable {
    case technique, fingerStrength, endurance, mobility, mental, beta, other
    var id: String { rawValue }

    var label: String {
        switch self {
        case .technique:      "Technik"
        case .fingerStrength: "Fingerkraft"
        case .endurance:      "Ausdauer"
        case .mobility:       "Beweglichkeit"
        case .mental:         "Mental"
        case .beta:           "Beta"
        case .other:          "Sonstiges"
        }
    }
}
