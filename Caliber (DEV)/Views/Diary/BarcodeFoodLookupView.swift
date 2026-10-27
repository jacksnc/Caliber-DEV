import HeliosDesign
import SwiftUI

/// Look book: the scan result card. Values are the provider's, for its stated basis; the
/// review screen is where the person checks them against the package and logs.
private struct BarcodeProductCard: View {
  let product: BarcodeNutritionProduct
  @Environment(\.heliosTheme) private var theme
  @Environment(\.locale) private var locale

  var body: some View {
    let data = theme.palette.data
    VStack(alignment: .leading, spacing: HeliosTokens.space(3)) {
      HStack(alignment: .top, spacing: HeliosTokens.space(3)) {
        Image(systemName: "shippingbox")
          .foregroundStyle(theme.palette.text.secondary.color)
          .frame(width: 44, height: 44)
          .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
              .fill(theme.palette.opaque.raised.color)
          )
          .accessibilityHidden(true)
        VStack(alignment: .leading, spacing: 2) {
          Text(product.name).heliosFont(.section)
            .fixedSize(horizontal: false, vertical: true)
          Text(
            [product.brand, product.sourceName].compactMap { $0 }.filter { !$0.isEmpty }
              .joined(separator: " · ")
          )
          .heliosFont(.footnote)
          .foregroundStyle(theme.palette.text.secondary.color)
          .fixedSize(horizontal: false, vertical: true)
        }
      }
      Text("Per \(product.basisDescription)")
        .heliosFont(.caption)
        .foregroundStyle(theme.palette.text.secondary.color)
        .fixedSize(horizontal: false, vertical: true)
      ViewThatFits(in: .horizontal) {
        HStack(spacing: HeliosTokens.space(2)) { tiles(data) }
        VStack(alignment: .leading, spacing: HeliosTokens.space(2)) { tiles(data) }
      }
      Label(product.sourceNote, systemImage: "exclamationmark.triangle.fill")
        .heliosFont(.caption)
        .foregroundStyle(theme.palette.text.secondary.color)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(.vertical, HeliosTokens.space(1))
  }

  @ViewBuilder private func tiles(_ data: DataColors) -> some View {
    tile("Energy", value: product.calories, unit: "kcal", color: data.energy.color)
    tile("Protein", value: product.proteinGrams, unit: "g", color: data.protein.color)
    tile("Carbs", value: product.carbGrams, unit: "g", color: data.carbs.color)
    tile("Fat", value: product.fatGrams, unit: "g", color: data.fat.color)
  }

  private func tile(_ title: String, value: Double, unit: String, color: Color) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack(spacing: 4) {
        Circle().fill(color).frame(width: 7, height: 7).accessibilityHidden(true)
        Text(title).heliosFont(.caption)
          .foregroundStyle(theme.palette.text.secondary.color)
      }
      Text(NutritionInput.format(value, locale: locale)).heliosFont(.bodyStrong)
      Text(unit).heliosFont(.caption)
        .foregroundStyle(theme.palette.text.secondary.color)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(HeliosTokens.space(2))
    .background { GlassBackground(level: .raised, cornerRadius: HeliosTokens.radius.tile) }
    .accessibilityElement(children: .combine)
  }
}

struct BarcodeFoodLookupView: View {
  @EnvironmentObject private var runtime: FoundationRuntime
  let mealType: MealType
  let date: Date
  init(mealType: MealType = .snack, date: Date = .now) {
    self.mealType = mealType
    self.date = date
  }
  @State private var coordinator: BarcodeLookupCoordinator?
  var body: some View {
    Group {
      if let coordinator {
        BarcodeLookupContent(coordinator: coordinator, mealType: mealType, date: date)
      } else {
        ProgressView("Opening barcode tools…")
      }
    }
    .navigationTitle("Barcode")
    .task {
      if coordinator == nil {
        coordinator = await BarcodeLookupCoordinator.configured(runtime: runtime)
      }
    }
  }
}

private struct BarcodeLookupContent: View {
  @ObservedObject var coordinator: BarcodeLookupCoordinator
  let mealType: MealType
  let date: Date
  @State private var code = ""
  @State private var showsScanner = false
  @State private var showsManualFood = false
  @State private var showsReview = false
  @State private var lookupTask: Task<Void, Never>?
  @FocusState private var codeHasFocus: Bool

  var body: some View {
    Form {
      Group {
        Section {
          Button {
            codeHasFocus = false
            showsScanner = true
          } label: {
            Label("Scan Barcode", systemImage: "barcode.viewfinder").frame(minHeight: 48)
          }.accessibilityIdentifier("barcodeOpenCamera")
          TextField("Barcode Numbers", text: $code)
            .focused($codeHasFocus)
            .keyboardType(.numberPad).textInputAutocapitalization(.never).autocorrectionDisabled()
            .accessibilityIdentifier("barcodeLookupCode")
          Text(
            "Camera images stay on your device. Offline products are checked on this device."
          )
          .font(.footnote)
        }
        if let count = coordinator.offlineFoodCount {
          Section("Offline Products") {
            Text(
              "\(count.formatted()) USDA packaged foods are available without an internet connection."
            )
            .accessibilityIdentifier("barcodeOfflineCoverage")
            Text(
              "This is a starting collection, not every product. Check your current package, serving and preparation before logging."
            )
            .font(.footnote)
          }
        }
        if let message = coordinator.offlineMessage { Section { Text(message) } }
        if coordinator.isConfigured {
          Section("Optional Online Lookup") {
            Toggle(
              "Allow Online Barcode Lookup",
              isOn: Binding(
                get: { coordinator.hasPermission },
                set: {
                  lookupTask?.cancel()
                  coordinator.setPermission($0)
                })
            )
            .accessibilityIdentifier("barcodePermission")
            Text(
              "The barcode and normal connection information go to Open Food Facts. No photos, diary, account token or personal health record is sent. You can turn this permission off here."
            )
            .font(.footnote)
          }
        } else if coordinator.offlineFoodCount == nil && coordinator.offlineMessage == nil {
          Section {
            Text(
              "Online product lookup is being set up. You can scan a code and enter its nutrition from the label."
            )
          }
        }
        Section {
          Button("Look Up Food") {
            codeHasFocus = false
            lookupTask?.cancel()
            lookupTask = Task { await coordinator.lookup(code) }
          }.disabled(!BarcodeValue.isValid(code) || coordinator.isBusy)
            .frame(minHeight: 48).accessibilityIdentifier("barcodeLookup")
          if coordinator.isBusy { ProgressView("Looking up food…") }
          if let message = coordinator.message {
            Text(message).accessibilityIdentifier("barcodeLookupMessage")
          }
        }
        if let product = coordinator.product {
          Section("Product Found") {
            BarcodeProductCard(product: product)
            // Look book: one primary action under the result card.
            Button {
              showsReview = true
            } label: {
              Text("Review and Log").frame(maxWidth: .infinity)
            }
            .buttonStyle(.heliosPrimary)
            .accessibilityIdentifier("barcodeReview")
          }
        }
        Section {
          Button("Enter Food from Label") { showsManualFood = true }
            .frame(minHeight: 48).accessibilityIdentifier("barcodeManualFood")
          Text("Missing product? Manual entry stays available offline.").font(.footnote)
        }
      }
      .listRowBackground(CaliberRowBackground())
    }
    .caliberScreen()
    .scrollDismissesKeyboard(.interactively)
    .toolbar {
      ToolbarItem(placement: .keyboard) {
        Button("Done") { codeHasFocus = false }
          .frame(minWidth: 48, minHeight: 48).accessibilityIdentifier("barcodeKeyboardDone")
      }
    }
    .fullScreenCover(isPresented: $showsScanner) {
      BarcodeScannerView { value in code = value }
    }
    .sheet(isPresented: $showsManualFood) {
      AddFoodView(mealType: mealType, date: date)
    }
    .navigationDestination(isPresented: $showsReview) {
      if let product = coordinator.product {
        FoodNutritionReviewView(reference: .barcode(product), meal: mealType, date: date)
      }
    }
    .onChange(of: code) { _, _ in
      lookupTask?.cancel()
      coordinator.cancel()
    }
    .onDisappear {
      lookupTask?.cancel()
      // A found result stays while its review is open; every request still has a cancellation guard.
      if coordinator.isBusy { coordinator.cancel() }
    }
  }
}
