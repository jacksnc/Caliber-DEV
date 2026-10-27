import Foundation
import Testing

@testable import Caliber__DEV_

@Suite("Nutrition label scan")
struct LabelScanTests {
  private let locale = Locale(identifier: "en_US")

  @Test func fdaSamplePanelFillsTheFormPerServing() {
    let scan = LabelScan.result(lines: LabelScan.fixtureLines, locale: locale)
    #expect(scan.isUsable)
    #expect(scan.prefill.servingDescription == "2/3 cup (55g)")
    #expect(scan.prefill.calories == "230")
    #expect(scan.prefill.protein == "3")
    #expect(scan.prefill.carbs == "37")
    #expect(scan.prefill.fat == "8")
    #expect(scan.prefill.name.isEmpty)
    #expect(scan.notes.isEmpty)
  }

  @Test func europeanTableIsPer100GramsAndSaysSo() {
    let scan = LabelScan.result(
      lines: [
        "Nutrition", "Typical values per 100g", "Energy 1046kJ / 250kcal", "Fat 10g",
        "of which saturates 2g", "Carbohydrate 30g", "of which sugars 5g", "Protein 9g",
        "Salt 0.5g",
      ], locale: locale)
    #expect(scan.prefill.servingDescription == "100 g")
    #expect(scan.prefill.calories == "250")
    #expect(scan.prefill.protein == "9")
    #expect(scan.notes.contains { $0.contains("per 100 g") })
  }

  @Test func missingValuesStayEmptyInsteadOfBeingGuessed() {
    let scan = LabelScan.result(
      lines: ["Nutrition Facts", "Serving size 1 bar (40g)", "Protein 10g"], locale: locale)
    #expect(!scan.isUsable)
    #expect(scan.prefill.calories.isEmpty)
    #expect(scan.prefill.carbs.isEmpty)
    #expect(scan.prefill.fat.isEmpty)
    #expect(scan.notes.contains { $0.contains("Calories were not read") })
  }
}
