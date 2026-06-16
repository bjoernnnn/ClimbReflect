import SwiftUI

// MARK: - Session-Typ (spiegelt iPhone-Enum)

enum WatchSessionType: String, CaseIterable, Identifiable {
    case boulder, lead, topRope, autoBelay, training
    var id: String { rawValue }

    var label: String {
        switch self {
        case .boulder:   "Bouldern"
        case .lead:      "Vorstieg"
        case .topRope:   "Toprope"
        case .autoBelay: "Autobelay"
        case .training:  "Training"
        }
    }

    var symbol: String {
        switch self {
        case .boulder:   "figure.climbing"
        case .lead:      "arrow.up.right"
        case .topRope:   "arrow.up"
        case .autoBelay: "arrow.up.to.line"
        case .training:  "dumbbell.fill"
        }
    }

    var defaultGradeSystem: WatchGradeSystem {
        switch self {
        case .boulder:            .fontainebleau
        case .lead, .topRope, .autoBelay: .french
        case .training:           .fontainebleau
        }
    }

    var usesBarometer: Bool { self == .lead || self == .topRope }
}

// MARK: - Grad-System

enum WatchGradeSystem: String, CaseIterable, Identifiable {
    case fontainebleau, vScale, french, uiaa
    var id: String { rawValue }

    var label: String {
        switch self {
        case .fontainebleau: "Fb"
        case .vScale:        "V"
        case .french:        "Fr"
        case .uiaa:          "UIAA"
        }
    }

    var grades: [String] {
        switch self {
        case .fontainebleau:
            ["3", "4", "4+", "5", "5+", "6A", "6A+", "6B", "6B+", "6C", "6C+",
             "7A", "7A+", "7B", "7B+", "7C", "7C+", "8A", "8A+", "8B", "8B+", "8C"]
        case .vScale:
            ["VB", "V0", "V1", "V2", "V3", "V4", "V5", "V6", "V7", "V8",
             "V9", "V10", "V11", "V12", "V13"]
        case .french:
            ["5a", "5b", "5c", "6a", "6a+", "6b", "6b+", "6c", "6c+",
             "7a", "7a+", "7b", "7b+", "7c", "7c+", "8a", "8a+", "8b"]
        case .uiaa:
            ["V-", "V", "V+", "VI-", "VI", "VI+", "VII-", "VII", "VII+",
             "VIII-", "VIII", "VIII+", "IX-", "IX", "IX+"]
        }
    }

    func sortOrder(of grade: String) -> Int {
        grades.firstIndex(of: grade) ?? 0
    }
}

// MARK: - Ergebnis

enum WatchAscentResult: String, CaseIterable, Identifiable {
    case top, attempt, quit
    var id: String { rawValue }

    var label: String {
        switch self {
        case .top:     "Top"
        case .attempt: "Versuch"
        case .quit:    "Abgebrochen"
        }
    }

    var symbol: String {
        switch self {
        case .top:     "checkmark.circle.fill"
        case .attempt: "arrow.clockwise.circle.fill"
        case .quit:    "xmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .top:     WatchTheme.accent
        case .attempt: WatchTheme.gold
        case .quit:    WatchTheme.danger
        }
    }
}

// MARK: - Session-Fragebogen

enum WatchSessionFocus: String, CaseIterable, Identifiable {
    case power, endurance, technique, project, casual
    var id: String { rawValue }
    var label: String {
        switch self {
        case .power:     "Kraft"
        case .endurance: "Ausdauer"
        case .technique: "Technik"
        case .project:   "Projekt"
        case .casual:    "Spaß"
        }
    }
    var symbol: String {
        switch self {
        case .power:     "bolt.fill"
        case .endurance: "wind"
        case .technique: "lightbulb.fill"
        case .project:   "scope"
        case .casual:    "star.fill"
        }
    }
}

enum WatchSessionEnergy: String, CaseIterable, Identifiable {
    case fresh, normal, tired
    var id: String { rawValue }
    var label: String {
        switch self {
        case .fresh:  "Frisch"
        case .normal: "Normal"
        case .tired:  "Müde"
        }
    }
    var symbol: String {
        switch self {
        case .fresh:  "leaf.fill"
        case .normal: "minus.circle.fill"
        case .tired:  "moon.zzz.fill"
        }
    }
    var color: Color {
        switch self {
        case .fresh:  WatchTheme.accent
        case .normal: WatchTheme.gold
        case .tired:  WatchTheme.danger
        }
    }
}

// MARK: - Trainingsziel (C5 – rawValue == Limiter.rawValue auf iPhone)

enum WatchTrainingTarget: String, CaseIterable, Identifiable {
    case fingerStrength, endurance, technique, mobility, mental
    var id: String { rawValue }

    var label: String {
        switch self {
        case .fingerStrength: "Fingerkraft"
        case .endurance:      "Ausdauer"
        case .technique:      "Technik"
        case .mobility:       "Beweglichkeit"
        case .mental:         "Mental"
        }
    }

    var symbol: String {
        switch self {
        case .fingerStrength: "hand.raised.fill"
        case .endurance:      "wind"
        case .technique:      "lightbulb.fill"
        case .mobility:       "figure.flexibility"
        case .mental:         "brain.head.profile"
        }
    }
}

// MARK: - Stil

enum WatchAscentStyle: String, CaseIterable, Identifiable {
    case flash, onsight, redpoint, project
    var id: String { rawValue }

    var label: String {
        switch self {
        case .flash:    "Flash"
        case .onsight:  "Onsight"
        case .redpoint: "Rotpunkt"
        case .project:  "Projekt"
        }
    }
}
