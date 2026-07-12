import Foundation
import SwiftData

@Model
final class ProjectMedia {
    // CK-P0: .unique entfernt + Default ergänzt (CloudKit-Voraussetzungen).
    var id: UUID = UUID()
    @Attribute(.externalStorage) var imageData: Data?
    var caption: String?
    var createdAt: Date = Date.now
    var project: Project?

    init(imageData: Data? = nil, caption: String? = nil) {
        self.id = UUID()
        self.imageData = imageData
        self.caption = caption
        self.createdAt = .now
    }
}
