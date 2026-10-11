import Foundation
import Testing
@testable import Caliber__DEV_

@MainActor
@Suite("Nutrition input")
struct NutritionInputTests {
    @Test("Fractional grams survive enabling and saving an adjustment")
    func decimalRoundTrip() {
        let original = 3.625
        #expect(NutritionInput.number(NutritionInput.format(original)) == original)
        let totals = NutritionInput.totals(calories: "165", protein: "31.25", carbs: "0", fat: "3.625")
        #expect(totals?.scaled(by: 2) == MacroTotals(calories: 330, protein: 62.5, carbs: 0, fat: 7.25))
    }

    @Test("Decimal-comma input is accepted in the matching locale")
    func localizedDecimals() {
        let locale = Locale(identifier: "fr_FR")
        #expect(NutritionInput.number("3,625", locale: locale) == 3.625)
        #expect(NutritionInput.format(3.625, locale: locale) == "3,625")
    }

    @Test("Invalid values cannot silently fall back to catalog nutrition")
    func invalidValues() {
        for input in ["", "abc", "-1", "nan", "inf", "1e999", "3.4.5"] {
            #expect(NutritionInput.number(input) == nil)
        }
        #expect(NutritionInput.number("0") == 0)
        #expect(NutritionInput.quantity("0") == nil)
        #expect(NutritionInput.quantity("-2") == nil)
        #expect(NutritionInput.quantity("0.5") == 0.5)
        #expect(NutritionInput.totals(calories: "100", protein: "oops", carbs: "3", fat: "2") == nil)
    }

    @Test("Overflow after scaling is not a valid diary total")
    func overflow() {
        #expect(!MacroTotals(calories: .greatestFiniteMagnitude).scaled(by: 2).isValid)
    }
    @Test("Locale changes keep every finite nutrition value intact")
    func preciseLocaleRoundTrips() {
        for locale in [Locale(identifier: "en_US"), Locale(identifier: "fr_FR"), Locale(identifier: "de_DE")] {
            for value in [0, 3.625, 0.00000001, Double.leastNonzeroMagnitude, Double.greatestFiniteMagnitude] {
                let text = NutritionInput.format(value, locale: locale)
                #expect(!text.contains("e"))
                #expect(NutritionInput.number(text, locale: locale) == value)
            }
        }
        #expect(NutritionInput.format(.nan).isEmpty)
        #expect(NutritionInput.format(.infinity).isEmpty)
        #expect(NutritionInput.reformatted("3.625", from: Locale(identifier: "en_US"), to: Locale(identifier: "de_DE")) == "3,625")
        #expect(NutritionInput.reformatted("invalid", from: Locale(identifier: "en_US"), to: Locale(identifier: "de_DE")) == "invalid")
    }

    @Test("The selected decimal format controls quantities and all macro fields")
    func selectedLocale() {
        let locale = Locale(identifier: "de_DE")
        #expect(NutritionInput.quantity("1,5", locale: locale) == 1.5)
        #expect(NutritionInput.quantity("1.5", locale: locale) == nil)
        #expect(NutritionInput.number("1.000", locale: locale) == nil)
        #expect(NutritionInput.number("1e3", locale: locale) == nil)
        #expect(NutritionInput.totals(calories: "100,5", protein: "10,25", carbs: "5,5", fat: "3,625", locale: locale) == MacroTotals(calories: 100.5, protein: 10.25, carbs: 5.5, fat: 3.625))
    }

}
