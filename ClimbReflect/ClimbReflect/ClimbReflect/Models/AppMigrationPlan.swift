import SwiftData

// V1 → V2: additive Änderungen (neue Tabellen Project/ProjectMedia, neue optionale
// Relationship Ascent.project). Lightweight migration genügt – kein Custom-Code nötig.
// V2 → V3: additive Änderungen (neue Tabelle Shoe, neue optionale Felder Ascent.shoe/shoeName).
// V3 → V4: additive Änderungen (Shoe.conditionRaw, Ascent.shoeCondition).
// V4 → V5: additive Änderungen (ClimbSession.conditionsRaw/temperatureC A8;
//           Shoe.isBuiltInDefault/defaultForTypesRaw SH-A/SH-B).

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

enum SchemaV4: VersionedSchema {
    static var versionIdentifier = Schema.Version(4, 0, 0)
    static var models: [any PersistentModel.Type] {
        [ClimbSession.self, Ascent.self, Project.self, ProjectMedia.self, Shoe.self]
    }
}

enum SchemaV5: VersionedSchema {
    static var versionIdentifier = Schema.Version(5, 0, 0)
    static var models: [any PersistentModel.Type] {
        [ClimbSession.self, Ascent.self, Project.self, ProjectMedia.self, Shoe.self]
    }
}

enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self, SchemaV3.self, SchemaV4.self, SchemaV5.self]
    }
    static var stages: [MigrationStage] { [v1ToV2, v2ToV3, v3ToV4, v4ToV5] }
    static let v1ToV2 = MigrationStage.lightweight(
        fromVersion: SchemaV1.self,
        toVersion: SchemaV2.self
    )
    static let v2ToV3 = MigrationStage.lightweight(
        fromVersion: SchemaV2.self,
        toVersion: SchemaV3.self
    )
    static let v3ToV4 = MigrationStage.lightweight(
        fromVersion: SchemaV3.self,
        toVersion: SchemaV4.self
    )
    static let v4ToV5 = MigrationStage.lightweight(
        fromVersion: SchemaV4.self,
        toVersion: SchemaV5.self
    )
}
