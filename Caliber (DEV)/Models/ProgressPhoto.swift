import Foundation
import SwiftData

/// Image bytes live outside the main database when SwiftData considers that useful.
@Model
final class ProgressPhoto {
    var id: UUID
    @Attribute(.externalStorage) var imageData: Data
    var sortOrder: Int = 0
    var progressEntry: ProgressEntry? = nil

    init(id: UUID = UUID(), imageData: Data, sortOrder: Int = 0) {
        self.id = id
        self.imageData = imageData
        self.sortOrder = sortOrder
    }
}

/// The form edits these values first, so Cancel never changes saved photos.
struct ProgressPhotoDraft: Identifiable {
    let id: UUID
    var imageData: Data

    init(id: UUID = UUID(), imageData: Data) {
        self.id = id
        self.imageData = imageData
    }
}
