import Foundation
import SwiftData

@Model
final class ProjectMedia {
    @Attribute(.unique) var id: UUID
    @Attribute(.externalStorage) var imageData: Data?
    var caption: String?
    var createdAt: Date
    var project: Project?

    init(imageData: Data? = nil, caption: String? = nil) {
        self.id = UUID()
        self.imageData = imageData
        self.caption = caption
        self.createdAt = .now
    }
}
