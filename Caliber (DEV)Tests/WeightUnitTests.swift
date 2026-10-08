import Foundation
import Testing
@testable import Caliber__DEV_

@Suite("Weight unit conversion")
struct WeightUnitTests {
    @Test("Pounds remain unchanged")
    func poundsAreIdentity() {
        #expect(WeightUnit.pounds.toPounds(185.25) == 185.25)
        #expect(WeightUnit.pounds.fromPounds(185.25) == 185.25)
        #expect(WeightUnit.pounds.symbol == "lb")
        #expect(WeightUnit.kilograms.symbol == "kg")
    }

    @Test("One pound is exactly 0.45359237 kilograms")
    func usesExactConversionFactor() {
        #expect(WeightUnit.kilograms.fromPounds(1) == 0.45359237)
        #expect(WeightUnit.kilograms.toPounds(0.45359237) == 1)
        #expect(abs(WeightUnit.kilograms.fromPounds(200) - 90.718474) < 0.000000001)
    }

    @Test("Finite weights survive conversion in either direction", arguments: [0.01, 40.5, 180.125, 500.0, 1000.0])
    func roundTrip(value: Double) {
        for unit in WeightUnit.allCases {
            let pounds = unit.toPounds(value)
            let returned = unit.fromPounds(pounds)
            #expect(pounds.isFinite)
            #expect(returned.isFinite)
            #expect(abs(returned - value) < 0.000000001)
            #expect(abs(unit.toPounds(unit.fromPounds(value)) - value) < 0.000000001)
        }
    }
}
