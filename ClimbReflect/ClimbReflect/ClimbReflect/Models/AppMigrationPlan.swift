import SwiftData

// V1 → V2: additive Änderungen (neue Tabellen Project/ProjectMedia, neue optionale
// Relationship Ascent.project). Lightweight migration genügt – kein Custom-Code nötig.

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

enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self]
    }
    static var stages: [MigrationStage] { [v1ToV2] }
    static let v1ToV2 = MigrationStage.lightweight(
        fromVersion: SchemaV1.self,
        toVersion: SchemaV2.self
    )
}
