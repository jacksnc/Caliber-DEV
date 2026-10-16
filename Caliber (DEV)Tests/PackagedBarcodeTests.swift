import CaliberDatabase
import Foundation
import Testing

@testable import Caliber__DEV_

@MainActor
private func packagedFixture(basis: String = "g", quantity: Double = 50) -> PackagedCatalogProduct {
  PackagedCatalogProduct(
    gtin14: "00012345678905", fdcID: 123, name: "Fictional label", brand: "Fixture Brand",
    publicationDate: "2026-04-30", modifiedDate: "2026-03-01",
    calories: 200, proteinGrams: 10, carbGrams: 25, fatGrams: 6,
    basisUnit: basis, servingQuantity: quantity, servingUnit: basis, servingLabel: nil,
    source: ReferenceCatalogSource(
      id: "usda-branded:2026-04", name: "USDA FoodData Central", dataType: "Branded",
      release: "2026-04", archiveURL: "https://fdc.nal.usda.gov/",
      archiveSHA256: String(repeating: "0", count: 64), license: "CC0-1.0"))
}

@MainActor @Test func packagedMassBasisScalesToItsSourceServingOnce() throws {
  let product = try BundledBarcodeService.product(
    packagedFixture(), requestedBarcode: "012345678905")
  #expect(product.calories == 100 && product.proteinGrams == 5)
  #expect(product.carbGrams == 12.5 && product.fatGrams == 3)
  #expect(product.basisGrams == 50 && product.sourceRecordID == "123")
  let reference = FoodNutritionReference.barcode(product)
  #expect(reference.name == "Fixture Brand · Fictional label")
  #expect(try reference.portionTotals(grams: 75).calories == 150)
}

@MainActor @Test func packagedVolumeBasisNeverTurnsIntoGrams() throws {
  let product = try BundledBarcodeService.product(
    packagedFixture(basis: "mL", quantity: 250), requestedBarcode: "0012345678905")
  #expect(product.calories == 500 && product.proteinGrams == 25)
  #expect(product.basisGrams == nil && product.basisDescription.contains("250 mL"))
  let reference = FoodNutritionReference.barcode(product)
  #expect(try reference.portionTotals(grams: nil).calories == 500)
  #expect(throws: FoodCatalogError.invalidPortion) { try reference.portionTotals(grams: 250) }
  #expect(try FoodPortionMath.resolve(value: 2, unit: .portions, basisGrams: nil).quantity == 2)
}

@MainActor @Test(arguments: [0.0, -1, Double.infinity, Double.nan])
func packagedSourceServingRejectsInvalidQuantity(_ quantity: Double) {
  #expect(throws: (any Error).self) {
    try BundledBarcodeService.product(
      packagedFixture(quantity: quantity), requestedBarcode: "012345678905")
  }
}

@MainActor @Test func packagedProductCannotReturnAnotherBarcodeOrUnknownBasis() {
  #expect(throws: BarcodeLookupError.invalidResponse) {
    try BundledBarcodeService.product(packagedFixture(), requestedBarcode: "4006381333931")
  }
  #expect(throws: BarcodeLookupError.invalidResponse) {
    try BundledBarcodeService.product(
      packagedFixture(basis: "oz"), requestedBarcode: "012345678905")
  }
}

@MainActor
private final class LocalBarcodeFixture: BarcodeService {
  var calls = 0
  var isMissing = false
  var waits = false
  var pending: CheckedContinuation<Void, Never>?
  func lookupFood(barcode: String) async throws -> BarcodeNutritionProduct {
    calls += 1
    if waits { await withCheckedContinuation { pending = $0 } }
    if isMissing { throw BarcodeLookupError.notFound }
    return try BundledBarcodeService.product(packagedFixture(), requestedBarcode: barcode)
  }
}

@MainActor @Test func localBarcodeWorksWithoutOnlinePermissionOrExternalCalls() async {
  let name = "Caliber.LocalBarcode.\(UUID().uuidString)"
  let defaults = UserDefaults(suiteName: name)!
  defer { defaults.removePersistentDomain(forName: name) }
  let local = LocalBarcodeFixture()
  let online = LocalBarcodeFixture()
  let model = BarcodeLookupCoordinator(
    service: online, isConfigured: true, preferences: defaults, offlineService: local,
    offlineFoodCount: 1)
  await model.lookup("012345678905")
  #expect(!model.hasPermission && model.product?.calories == 100)
  #expect(local.calls == 1 && online.calls == 0)
  #expect(defaults.dictionaryRepresentation().keys.allSatisfy { !$0.contains("permission.date") })
}

@MainActor @Test func aLocalMissCannotStartAnOnlineRequestWithoutPermission() async {
  let name = "Caliber.LocalBarcode.\(UUID().uuidString)"
  let defaults = UserDefaults(suiteName: name)!
  defer { defaults.removePersistentDomain(forName: name) }
  let local = LocalBarcodeFixture()
  local.isMissing = true
  let online = LocalBarcodeFixture()
  let model = BarcodeLookupCoordinator(
    service: online, isConfigured: true, preferences: defaults, offlineService: local)
  await model.lookup("012345678905")
  #expect(local.calls == 1 && online.calls == 0 && model.product == nil)
  model.setPermission(true)
  await model.lookup("012345678905")
  #expect(local.calls == 2 && online.calls == 1 && model.product != nil)
}

@MainActor @Test func cancelingALocalMissCannotLeakTheOldCodeOnline() async throws {
  let name = "Caliber.LocalBarcode.\(UUID().uuidString)"
  let defaults = UserDefaults(suiteName: name)!
  defer { defaults.removePersistentDomain(forName: name) }
  let local = LocalBarcodeFixture()
  local.isMissing = true
  local.waits = true
  let online = LocalBarcodeFixture()
  let model = BarcodeLookupCoordinator(
    service: online, isConfigured: true, preferences: defaults, offlineService: local)
  model.setPermission(true)
  let task = Task { await model.lookup("012345678905") }
  for _ in 0..<1_000 where local.pending == nil { await Task.yield() }
  let pending = try #require(local.pending)
  model.cancel()
  pending.resume()
  await task.value
  #expect(online.calls == 0 && model.product == nil && !model.isBusy)
}

@MainActor @Test func anUnconfiguredOnlineProviderDoesNotHideOfflineMisses() async {
  let name = "Caliber.LocalBarcode.\(UUID().uuidString)"
  let defaults = UserDefaults(suiteName: name)!
  defer { defaults.removePersistentDomain(forName: name) }
  let local = LocalBarcodeFixture()
  local.isMissing = true
  let model = BarcodeLookupCoordinator(
    service: DisabledBarcodeService(), isConfigured: false, preferences: defaults,
    offlineService: local)
  await model.lookup("012345678905")
  #expect(model.message == BarcodeLookupError.notFound.errorDescription && !model.isBusy)
}

@MainActor @Test func bundledPackagedCollectionResolvesRealMassAndVolumeRecordsOffline()
  async throws
{
  let prepared = await BundledBarcodeService.prepared()
  #expect(prepared.count == 50_000)
  let service = try #require(prepared.service)
  let cereal = try await service.lookupFood(barcode: "016000482685")
  #expect(cereal.sourceRecordID == "2212186" && cereal.basisGrams == 28)
  #expect(abs(cereal.calories - 110.04) < 1e-10)
  let equivalent = try await service.lookupFood(barcode: "0016000482685")
  #expect(
    equivalent.calories == cereal.calories && equivalent.sourceRecordID == cereal.sourceRecordID)
  let drink = try await service.lookupFood(barcode: "000020072353")
  #expect(drink.sourceRecordID == "2475195" && drink.basisGrams == nil)
  #expect(drink.calories == 110 && drink.basisDescription.contains("250 mL"))
  do {
    _ = try await service.lookupFood(barcode: "00000000000000")
    Issue.record("A reserved all-zero code cannot match a product.")
  } catch { #expect(error as? BarcodeLookupError == .notFound) }
}
