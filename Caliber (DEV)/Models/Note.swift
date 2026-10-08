//
//  Note.swift
//  Caliber (DEV)
//

import Foundation
import SwiftData

/// A free-form note attached to a day, or optionally to one specific diary entry.
@Model
final class Note {
    var id: UUID
    var date: Date
    var text: String
    var linkedDiaryEntry: DiaryEntry?

    init(date: Date, text: String, linkedDiaryEntry: DiaryEntry? = nil) {
        self.id = UUID()
        self.date = date
        self.text = text
        self.linkedDiaryEntry = linkedDiaryEntry
    }
}
