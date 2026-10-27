import FoodCore
import Foundation
import Vision

/// Values handed to the manual food form for the person to check before saving.
struct FoodEntryPrefill: Equatable {
  var name = ""
  var servingDescription = ""
  var calories = ""
  var protein = ""
  var carbs = ""
  var fat = ""
}

/// A nutrition-facts panel read from a photo on this device (FUEL-11). Text recognition and
/// `LabelParser` supply the values; nothing is filled in that the label did not show.
struct LabelScanResult: Equatable {
  let label: ParsedLabel
  let prefill: FoodEntryPrefill
  /// Plain-language checks for the confirmation screen.
  let notes: [String]
  /// Rows read with low confidence or repaired from %DV; the screen marks them.
  let rowsToCheck: Set<String>

  var isUsable: Bool { label.isUsable }
}

enum LabelScan {
  /// Builds the result from recognised lines. Values are formatted with `locale`.
  static func result(lines: [String], locale: Locale) -> LabelScanResult {
    let label = LabelParser.parse(lines: lines)
    let values = label.nutrientSet
    func text(_ value: Double?) -> String {
      value.map { NutritionInput.format($0, locale: locale) } ?? ""
    }
    let serving: String =
      switch label.basis {
      case .per100g: "100 g"
      case .per100ml: "100 ml"
      case .perServing: label.servingText ?? ""
      }
    let prefill = FoodEntryPrefill(
      servingDescription: serving,
      calories: text(values.calories),
      protein: text(values.proteinG),
      carbs: text(values.carbsG),
      fat: text(values.fatG))

    var notes: [String] = []
    for warning in label.warnings {
      switch warning {
      case .missingCalories:
        notes.append("Calories were not read. Enter them from the label.")
      case .missingMacros(let missing):
        let names = missing.map(name(of:)).joined(separator: ", ")
        notes.append("Not read: \(names). Enter them from the label.")
      case .percentDailyValueMismatch(let nutrient, _):
        notes.append("\(name(of: nutrient)) and its % Daily Value disagree. Check that row.")
      case .energyMismatch(let declared, let atwater):
        notes.append(
          "Calories (\(text(declared))) differ from protein, carbs and fat (\(text(atwater))) by more than the label rounding allows. Check the label."
        )
      }
    }
    if label.basis != .perServing {
      notes.append("This label lists values per \(serving). Change the quantity to what you ate.")
    }
    let rowsToCheck = Set(label.needsConfirmation.map(name(of:)))
    return LabelScanResult(label: label, prefill: prefill, notes: notes, rowsToCheck: rowsToCheck)
  }

  /// Reads text from a photo with Vision on this device and rebuilds the printed rows.
  static func recognizeLines(in image: CGImage) async throws -> [String] {
    try await withCheckedThrowingContinuation { continuation in
      let request = VNRecognizeTextRequest { request, error in
        if let error {
          continuation.resume(throwing: error)
          return
        }
        let observations = request.results as? [VNRecognizedTextObservation] ?? []
        let fragments = observations.compactMap { observation -> TextFragment? in
          guard let candidate = observation.topCandidates(1).first else { return nil }
          let box = observation.boundingBox
          return TextFragment(
            text: candidate.string, minX: box.minX, midY: box.midY, height: box.height)
        }
        continuation.resume(returning: TextRowAssembler.rows(from: fragments))
      }
      request.recognitionLevel = .accurate
      request.usesLanguageCorrection = false
      do {
        try VNImageRequestHandler(cgImage: image).perform([request])
      } catch {
        continuation.resume(throwing: error)
      }
    }
  }

  static func name(of nutrient: Nutrient) -> String {
    switch nutrient {
    case .energyKcal: "Calories"
    case .protein: "Protein"
    case .carbohydrate: "Carbs"
    case .fat: "Fat"
    default: nutrient.rawValue
    }
  }

  #if DEBUG
    /// The FDA's public-domain sample panel, for UI tests (`--label-fixture`).
    static let fixtureLines = [
      "Nutrition Facts", "8 servings per container", "Serving size 2/3 cup (55g)",
      "Amount per serving", "Calories 230", "% Daily Value*", "Total Fat 8g 10%",
      "Saturated Fat 1g 5%", "Trans Fat 0g", "Cholesterol 0mg 0%", "Sodium 160mg 7%",
      "Total Carbohydrate 37g 13%", "Dietary Fiber 4g 14%", "Total Sugars 12g",
      "Includes 10g Added Sugars 20%", "Protein 3g",
    ]
  #endif
}
