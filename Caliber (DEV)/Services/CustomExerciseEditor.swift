import Foundation
import SwiftData

enum CustomExerciseError: LocalizedError, Equatable {
  case missingName, duplicateName

  var errorDescription: String? {
    switch self {
    case .missingName:
      String(localized: "Enter a name for this exercise.", table: "CustomExercises")
    case .duplicateName:
      String(
        localized:
          "An exercise with this name already exists. Choose it from the list or use a different name.",
        table: "CustomExercises")
    }
  }
}

@MainActor
enum CustomExerciseEditor {
  /// Creates one personal exercise and saves it before a picker can select it.
  /// The current manual editor uses weight and reps; more metric editors remain
  /// a separate integration task rather than offering fields that cannot log.
  static func create(
    name: String, aliases: String, in context: ModelContext
  ) throws -> TrainingExercise {
    let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty else { throw CustomExerciseError.missingName }
    let key = normalizedName(name)
    let existing = try context.fetch(FetchDescriptor<TrainingExercise>())
    guard !existing.contains(where: { normalizedName($0.name) == key }) else {
      throw CustomExerciseError.duplicateName
    }
    let exercise = TrainingExercise(
      name: name, aliases: aliases.trimmingCharacters(in: .whitespacesAndNewlines),
      metricType: .weightAndReps, isCustom: true)
    context.insert(exercise)
    do { try context.save() } catch {
      context.rollback()
      throw error
    }
    return exercise
  }

  private static func normalizedName(_ text: String) -> String {
    text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
      .folding(
        options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
        locale: Locale(identifier: "en_US_POSIX"))
  }
}
