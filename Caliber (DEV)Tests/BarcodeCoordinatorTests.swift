import Foundation
import Testing

@testable import Caliber__DEV_

@MainActor
private final class CoordinatorBarcodeFixture: BarcodeService {
  var calls = 0
  var code = "012345678905"
  var failure: Error?
  var waits = false
  var pending: CheckedContinuation<Void, Never>?
  func lookupFood(barcode: String) async throws -> BarcodeNutritionProduct {
    calls += 1
    if waits { await withCheckedContinuation { pending = $0 } }
    if let failure { throw failure }
    return BarcodeNutritionProduct(
      barcode: code, name: "Fictional product", brand: nil,
      calories: 200, proteinGrams: 10, carbGrams: 25, fatGrams: 6,
      basisDescription: "50 g", basisGrams: 50,
      sourceURL: URL(string: "https://example.invalid/fixture")!,
      sourceName: "Fixture", attribution: "Fictional")
  }
}

@MainActor
private func withBarcodeModel(
  configured: Bool = true,
  body: (BarcodeLookupCoordinator, CoordinatorBarcodeFixture, UserDefaults) async throws -> Void
) async rethrows {
  let name = "Caliber.Barcode.Tests." + UUID().uuidString
  let defaults = UserDefaults(suiteName: name)!
  defer { defaults.removePersistentDomain(forName: name) }
  let service = CoordinatorBarcodeFixture()
  let model = BarcodeLookupCoordinator(
    service: service, isConfigured: configured, preferences: defaults)
  try await body(model, service, defaults)
}

@MainActor @Test func barcodePermissionAndValidationGateEveryRequest() async throws {
  await withBarcodeModel { model, service, _ in
    await model.lookup("012345678905")
    #expect(service.calls == 0 && !model.isBusy && model.product == nil)
    model.setPermission(true)
    await model.lookup("123")
    #expect(service.calls == 0 && model.message != nil)
    await model.lookup("012345678905")
    #expect(service.calls == 1 && model.product?.name == "Fictional product")
    model.setPermission(false)
    #expect(model.product == nil && model.message == nil && !model.hasPermission)
    await model.lookup("012345678905")
    #expect(service.calls == 1)
  }
  await withBarcodeModel(configured: false) { model, service, _ in
    model.setPermission(true)
    await model.lookup("012345678905")
    #expect(service.calls == 0 && model.product == nil && model.message != nil)
  }
}

@MainActor @Test func barcodePermissionIsVersionedAndSurvivesOnlyUntilWithdrawal() async {
  await withBarcodeModel { model, service, defaults in
    model.setPermission(true)
    let reopened = BarcodeLookupCoordinator(
      service: service, isConfigured: true, preferences: defaults)
    #expect(reopened.hasPermission)
    reopened.setPermission(false)
    let third = BarcodeLookupCoordinator(
      service: service, isConfigured: true, preferences: defaults)
    #expect(!third.hasPermission)
    #expect(defaults.object(forKey: "food.barcode.open-food-facts.permission.date") == nil)
  }
}

@MainActor @Test func barcodeEquivalentEANAcceptedAndMismatchedProductRejected() async {
  await withBarcodeModel { model, service, _ in
    model.setPermission(true)
    service.code = "0012345678905"
    await model.lookup("012345678905")
    #expect(model.product?.barcode == service.code)
    service.code = "4006381333931"
    await model.lookup("012345678905")
    #expect(
      model.product == nil && model.message == BarcodeLookupError.invalidResponse.errorDescription)
  }
}

@MainActor @Test(arguments: [true, false])
func lateBarcodeResultCannotPublishAfterWithdrawalOrCancellation(withdraw: Bool) async throws {
  try await withBarcodeModel { model, service, _ in
    service.waits = true
    model.setPermission(true)
    let request = Task { await model.lookup("012345678905") }
    for _ in 0..<1_000 where service.pending == nil { await Task.yield() }
    let pending = try #require(service.pending)
    #expect(model.isBusy && service.calls == 1)
    if withdraw {
      model.setPermission(false)
    } else {
      model.cancel()
      request.cancel()
    }
    pending.resume()
    await request.value
    #expect(model.product == nil && model.message == nil && !model.isBusy)
  }
}

@MainActor @Test func arbitraryBarcodeErrorsNeverExposeProviderBody() async {
  struct PrivateFailure: LocalizedError {
    var errorDescription: String? { "private provider body" }
  }
  await withBarcodeModel { model, service, _ in
    model.setPermission(true)
    service.failure = PrivateFailure()
    await model.lookup("012345678905")
    #expect(model.message == BarcodeLookupError.providerUnavailable.errorDescription)
    #expect(model.product == nil && !model.isBusy)
  }
}

@MainActor @Test func bundledBarcodeProviderIsDisabledUntilOwnerSetup() {
  #expect(FoodLookupConfiguration.load()?.provider == "pending")
  #expect(FoodLookupConfiguration.load()?.configuredService() == nil)
}

@MainActor @Test func canceledBarcodeLookupDoesNotStartAProviderRequest() async {
  await withBarcodeModel { model, service, _ in
    model.setPermission(true)
    let task = Task { await model.lookup("012345678905") }
    task.cancel()
    await task.value
    #expect(service.calls == 0 && model.product == nil && !model.isBusy)
  }
}
