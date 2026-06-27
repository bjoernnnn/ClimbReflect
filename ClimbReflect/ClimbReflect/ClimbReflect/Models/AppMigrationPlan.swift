import SwiftData

// V1 → V2: additive Änderungen (neue Tabellen Project/ProjectMedia, neue optionale
// Relationship Ascent.project). Lightweight migration genügt – kein Custom-Code nötig.
// V2 → V3: additive Änderungen (neue Tabelle Shoe, neue optionale Felder Ascent.shoe/shoeName).

enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [ClimbSession.self, Ascent.self]
    }
}

enum SchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] {
        [ClimbSession.self, Ascent.self, Project.self, ProjectMedia.self]
    }
}

enum SchemaV3: VersionedSchema {
    static var versionIdentifier = Schema.Version(3, 0, 0)
    static var models: [any PersistentModel.Type] {
        [ClimbSession.self, Ascent.self, Project.self, ProjectMedia.self, Shoe.self]
    }
}

enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self, SchemaV3.self]
    }
    static var stages: [MigrationStage] { [v1ToV2, v2ToV3] }
    static let v1ToV2 = MigrationStage.lightweight(
        fromVersion: SchemaV1.self,
        toVersion: SchemaV2.self
    )
    static let v2ToV3 = MigrationStage.lightweight(
        fromVersion: SchemaV2.self,
        toVersion: SchemaV3.self
    )
}
