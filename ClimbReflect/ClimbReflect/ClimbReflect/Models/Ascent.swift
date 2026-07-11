import Foundation
import SwiftData

@Model
final class Ascent {
    // CK-P0: .unique entfernt (CloudKit unterstützt keine Unique-Constraints) +
    // Defaults ergänzt (CloudKit verlangt optional-oder-Default für jedes Attribut).
    // Dedupe bleibt app-seitig (z. B. WatchSessionReceiver-Upsert über watchSessionID).
    var id: UUID = UUID()
    var gradeSystemRaw: String = ""
    var gradeRaw: String = ""
    var resultRaw: String = ""
    var styleRaw: String?
    var attempts: Int = 1
    var note: String?
    var date: Date = Date.now

    // Stil-Tags (P3.7)
    var wallAngleRaw: String?
    var holdTypeRaw: String?
    var climbStyleRaw: String?

    // Projekt-Zugehörigkeit: projectName als Migration-Cache, project als echte Relation
    var projectName: String?
    var project: Project?

    // Kletterhöhe (B1 – Watch-Barometer, optional manuell)
    var altitudeGain: Double = 0
    // Versuchdauer aus dem Action-Button-Flow (optional, nur Watch)
    var durationSeconds: Double?
    // RP-6: HF-Snapshot beim Banken auf der Uhr (optional, nur Watch)
    var heartRateAtBanking: Double?

    // Schuh-Zugehörigkeit: shoeName als Cache, shoe als echte Relation (SH-1)
    var shoeName: String?
    var shoe: Shoe?
    var shoeCondition: String?  // Snapshot von Shoe.conditionRaw zum Zeitpunkt des Bankens

    // Gym-/Set-Kontext (P3.13)
    var setName: String?               // z. B. "Gelb rechts", "Sektor B"

    // Medien (P3.11) — externalStorage hält die SwiftData-Hauptdatei klein
    @Attribute(.externalStorage) var photoData: Data?

    var session: ClimbSession?
    var createdAt: Date = Date.now

    init(id: UUID = UUID(),
         gradeSystem: GradeSystem,
         grade: String,
         result: AscentResult,
         style: AscentStyle? = nil,
         attempts: Int = 1,
         note: String? = nil,
         date: Date = .now,
         wallAngle: WallAngle? = nil,
         holdType: HoldType? = nil,
         climbStyle: ClimbStyle? = nil,
         projectName: String? = nil,
         session: ClimbSession? = nil) {
        self.id = id
        self.gradeSystemRaw = gradeSystem.rawValue
        self.gradeRaw = grade
        self.resultRaw = result.rawValue
        self.styleRaw = style?.rawValue
        self.attempts = attempts
        self.note = note
        self.date = date
        self.wallAngleRaw = wallAngle?.rawValue
        self.holdTypeRaw = holdType?.rawValue
        self.climbStyleRaw = climbStyle?.rawValue
        self.projectName = projectName
        self.session = session
        self.createdAt = .now
    }
}

extension Ascent {
    /// RP-5: Sentinel für Begehungen ohne erfassten Grad (z. B. Quick-Bank auf der Uhr).
    static let ungraded = "?"
    /// true, wenn ein echter Grad hinterlegt ist (nicht Sentinel/leer). Grad-basierte
    /// Auswertungen (Pyramide, PB, Max-Trend) müssen ungegradete Begehungen ausschließen.
    var isGraded: Bool {
        !gradeRaw.isEmpty && gradeRaw != Self.ungraded
    }

    var gradeSystem: GradeSystem { GradeSystem(rawValue: gradeSystemRaw) ?? .fontainebleau }
    var result: AscentResult { AscentResult(rawValue: resultRaw) ?? .attempt }
    var style: AscentStyle? { styleRaw.flatMap(AscentStyle.init(rawValue:)) }
    var wallAngle: WallAngle? { wallAngleRaw.flatMap(WallAngle.init(rawValue:)) }
    var holdType: HoldType? { holdTypeRaw.flatMap(HoldType.init(rawValue:)) }
    var climbStyle: ClimbStyle? { climbStyleRaw.flatMap(ClimbStyle.init(rawValue:)) }
    var sortOrder: Int { gradeSystem.sortOrder(of: gradeRaw) }
    /// Skalenübergreifend vergleichbare Schwierigkeit (gemeinsame Leiter pro Disziplin).
    /// Für Grade außerhalb der Umrechnungs-Leiter Fallback auf den eigenen Skala-Index.
    var canonicalOrder: Int {
        GradeConverter.canonicalIndex(grade: gradeRaw, system: gradeSystem) ?? sortOrder
    }
}
