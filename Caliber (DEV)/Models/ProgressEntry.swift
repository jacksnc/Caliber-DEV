import Foundation
import SwiftData

/// One day's check-in. Weight, notes, and photos can each be left out.
@Model
final class ProgressEntry {
    var id: UUID
    var date: Date
    var notes: String

    @Relationship(deleteRule: .cascade, inverse: \WeightEntry.progressEntry)
    var weightEntry: WeightEntry?

    @Relationship(deleteRule: .cascade, inverse: \ProgressPhoto.progressEntry)
    var photos: [ProgressPhoto] = []

    init(date: Date, notes: String = "", weightEntry: WeightEntry? = nil, photos: [ProgressPhoto] = []) {
        self.id = UUID()
        self.date = date
        self.notes = notes
        self.weightEntry = weightEntry
        self.photos = photos
    }

    /// SwiftData relationships do not preserve array order across launches.
    var sortedPhotos: [ProgressPhoto] {
        photos.sorted {
            if $0.sortOrder == $1.sortOrder { return $0.id.uuidString < $1.id.uuidString }
            return $0.sortOrder < $1.sortOrder
        }
    }
}
