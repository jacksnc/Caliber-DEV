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
  @State private var lookupTask: Task<Void, Never>?
  @FocusState private var codeHasFocus: Bool

  var body: some View {
    Form {
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
          NavigationLink {
            FoodNutritionReviewView(reference: .barcode(product), meal: mealType, date: date)
          } label: {
            VStack(alignment: .leading, spacing: 4) {
              Text(product.name)
              if let brand = product.brand, !brand.isEmpty { Text(brand).font(.subheadline) }
              Text(product.basisDescription).font(.footnote).foregroundStyle(.secondary)
              Text("Review Nutrition").font(.subheadline)
            }.frame(minHeight: 48)
          }.accessibilityIdentifier("barcodeReview")
        }
      }
      Section {
        Button("Enter Food from Label") { showsManualFood = true }
          .frame(minHeight: 48).accessibilityIdentifier("barcodeManualFood")
        Text("Missing product? Manual entry stays available offline.").font(.footnote)
      }
    }
    .scrollDismissesKeyboard(.interactively)
    .toolbar {
      ToolbarItem(placement: .keyboard) {
        Button("Done") { codeHasFocus = false }
          .frame(minWidth: 48, minHeight: 48).accessibilityIdentifier("barcodeKeyboardDone")
      }
    }
    .sheet(isPresented: $showsScanner) {
      BarcodeScannerView { value in code = value }
    }
    .sheet(isPresented: $showsManualFood) {
      AddFoodView(mealType: mealType, date: date)
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
