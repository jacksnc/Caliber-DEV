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
    .task { if coordinator == nil { coordinator = .configured(runtime: runtime) } }
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

  var body: some View {
    Form {
      Section {
        Button {
          showsScanner = true
        } label: {
          Label("Scan Barcode", systemImage: "barcode.viewfinder").frame(minHeight: 48)
        }.accessibilityIdentifier("barcodeOpenCamera")
        TextField("Barcode Numbers", text: $code)
          .keyboardType(.numberPad).textInputAutocapitalization(.never).autocorrectionDisabled()
          .accessibilityIdentifier("barcodeLookupCode")
        Text(
          "Camera images stay on your device. A lookup sends only the barcode to the food provider."
        )
        .font(.footnote)
      }
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
      } else {
        Section {
          Text(
            "Online product lookup is being set up. You can scan a code and enter its nutrition from the label."
          )
        }
      }
      Section {
        Button("Look Up Food") {
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
