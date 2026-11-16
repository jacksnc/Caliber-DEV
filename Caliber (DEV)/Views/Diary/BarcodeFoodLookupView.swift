import HeliosDesign
import SwiftUI

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
  /// The amount chosen on the result sheet or panel; nil opens the review on its default.
  @State private var reviewPortion: ScannedPortion?
  /// The camera's sheet asked for the review; it opens once the camera has closed.
  @State private var reviewAfterScanner = false
  @State private var switchedMode: FoodCaptureMode?
  @Environment(\.dismiss) private var dismiss
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
            // Look book: the camera's product sheet, here as a card, so a typed code and a
            // scanned one read alike. It only opens the editable review; saving happens there.
            ScannedProductPanel(
              product: product, mealType: mealType, idPrefix: "found",
              reviewIdentifier: "barcodeReview"
            ) { portion in
              reviewPortion = portion
              showsReview = true
            }
            .id(product.barcode)
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
    .fullScreenCover(isPresented: $showsScanner, onDismiss: openRequestedReview) {
      BarcodeScannerView(
        onScanned: { value in code = value },
        onSwitchMode: { mode in
          if mode == .search {
            // Back to food search, which this screen was opened from.
            Task { @MainActor in dismiss() }
          } else {
            switchedMode = mode
          }
        },
        coordinator: coordinator, mealType: mealType,
        onReview: { portion in
          reviewPortion = portion
          reviewAfterScanner = true
        })
    }
    .sheet(isPresented: $showsManualFood) {
      AddFoodView(mealType: mealType, date: date)
    }
    .navigationDestination(item: $switchedMode) { mode in
      switch mode {
      case .label: LabelScannerView(mealType: mealType, date: date)
      case .photo: PhotoEstimateView(mealType: mealType, date: date)
      case .barcode, .search: EmptyView()
      }
    }
    .navigationDestination(isPresented: $showsReview) {
      if let product = coordinator.product {
        FoodNutritionReviewView(
          reference: .barcode(product), meal: mealType, date: date,
          portion: reviewPortion.map { (choiceID: $0.choiceID, amount: $0.amount) })
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

  /// The camera's result sheet asked for the review. It opens here once the camera is gone,
  /// on the same editable screen as a typed code.
  private func openRequestedReview() {
    guard reviewAfterScanner else { return }
    reviewAfterScanner = false
    showsReview = true
  }
}
