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
    case watch       // direkt von Apple Watch via WatchConnectivity
}

// MARK: - Grad-System

enum GradeSystem: String, Codable, CaseIterable, Identifiable {
    case fontainebleau, vScale, french, uiaa
    var id: String { rawValue }

    var label: String {
        switch self {
        case .fontainebleau: "Fb (Boulder)"
        case .vScale:        "V-Scale (Boulder)"
        case .french:        "French (Route)"
        case .uiaa:          "UIAA (Route)"
        }
    }

    var grades: [String] {
        switch self {
        case .fontainebleau:
            ["3", "4", "4+", "5", "5+", "6A", "6A+", "6B", "6B+", "6C", "6C+",
             "7A", "7A+", "7B", "7B+", "7C", "7C+", "8A", "8A+", "8B", "8B+", "8C", "8C+", "9A"]
        case .vScale:
            ["VB", "V0", "V1", "V2", "V3", "V4", "V5", "V6", "V7", "V8",
             "V9", "V10", "V11", "V12", "V13", "V14", "V15", "V16", "V17"]
        case .french:
            ["4", "4+", "5a", "5b", "5c", "6a", "6a+", "6b", "6b+", "6c", "6c+",
             "7a", "7a+", "7b", "7b+", "7c", "7c+", "8a", "8a+", "8b", "8b+", "8c", "8c+", "9a"]
        case .uiaa:
            ["III", "IV", "IV+", "V-", "V", "V+", "VI-", "VI", "VI+",
             "VII-", "VII", "VII+", "VIII-", "VIII", "VIII+", "IX-", "IX", "IX+", "X-", "X", "X+"]
        }
    }

    func sortOrder(of grade: String) -> Int {
        grades.firstIndex(of: grade) ?? 0
    }
}

// MARK: - Begehungsergebnis

enum AscentResult: String, Codable, CaseIterable, Identifiable {
    case top, attempt, quit
    var id: String { rawValue }

    var label: String {
        switch self {
        case .top:     "Top"
        case .attempt: "Versuch"
        case .quit:    "Aufgegeben"
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
        case .top:     Theme.accent
        case .attempt: Theme.gold
        case .quit:    Theme.danger
        }
    }
}

// MARK: - Technik-Fokus (P3.6)

enum TechniqueFocus: String, Codable, CaseIterable, Identifiable {
    case footwork, hipPlacement, dynamicMoves, heelHooks, toeHooks,
         balance, compression, slopers, crimps, overhangs, slabs, coordination
    var id: String { rawValue }

    var label: String {
        switch self {
        case .footwork:     "Stille Füße"
        case .hipPlacement: "Hüfte an die Wand"
        case .dynamicMoves: "Dynamos committen"
        case .heelHooks:    "Heel-Hooks"
        case .toeHooks:     "Toe-Hooks"
        case .balance:      "Balance & Gewicht"
        case .compression:  "Kompression"
        case .slopers:      "Sloper"
        case .crimps:       "Crimps"
        case .overhangs:    "Überhänge"
        case .slabs:        "Platten"
        case .coordination: "Koordination"
        }
    }

    var symbol: String {
        switch self {
        case .footwork:     "shoe.fill"
        case .hipPlacement: "figure.dance"
        case .dynamicMoves: "bolt.fill"
        case .heelHooks, .toeHooks: "figure.cooldown"
        case .balance:      "scale.3d"
        case .compression:  "arrow.down.to.line.alt"
        case .slopers, .crimps: "hand.point.up.left.fill"
        case .overhangs:    "chevron.up"
        case .slabs:        "rectangle.portrait"
        case .coordination: "arrow.triangle.2.circlepath"
        }
    }
}

// MARK: - Begehungsstil (nur bei Top relevant)

enum AscentStyle: String, Codable, CaseIterable, Identifiable {
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

    var symbol: String {
        switch self {
        case .flash:    "bolt.fill"
        case .onsight:  "eye.fill"
        case .redpoint: "star.fill"
        case .project:  "target"
        }
    }
}

// MARK: - Wand-Winkel, Grifftyp, Kletter-Stil (P3.7)

enum WallAngle: String, Codable, CaseIterable, Identifiable {
    case slab, vertical, overhang, roof
    var id: String { rawValue }
    var label: String {
        switch self {
        case .slab:     "Platte"
        case .vertical: "Senkrecht"
        case .overhang: "Überhang"
        case .roof:     "Dach"
        }
    }
    var symbol: String {
        switch self {
        case .slab:     "rectangle.portrait.slash"
        case .vertical: "rectangle.portrait"
        case .overhang: "chevron.up"
        case .roof:     "arrow.up.to.line"
        }
    }
}

enum HoldType: String, Codable, CaseIterable, Identifiable {
    case crimps, slopers, pinches, pockets, jugs, volumes
    var id: String { rawValue }
    var label: String {
        switch self {
        case .crimps:  "Crimps"
        case .slopers: "Sloper"
        case .pinches: "Pinch"
        case .pockets: "Taschen"
        case .jugs:    "Henkel"
        case .volumes: "Volumen"
        }
    }
}

enum ClimbStyle: String, Codable, CaseIterable, Identifiable {
    case technical, powerful, dynamic
    var id: String { rawValue }
    var label: String {
        switch self {
        case .technical: "Technisch"
        case .powerful:  "Kraftvoll"
        case .dynamic:   "Dynamisch"
        }
    }
}

// MARK: - Limiter

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
