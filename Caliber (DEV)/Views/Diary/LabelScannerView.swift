import HeliosDesign
import PhotosUI
import SwiftUI
import UIKit

/// Reads a nutrition-facts panel from a photo on this device (FUEL-11) and hands the values to
/// the manual food form, where the person checks and saves them. Photos never leave the device.
struct LabelScannerView: View {
  let mealType: MealType
  let date: Date
  @Environment(\.locale) private var locale
  @Environment(\.heliosTheme) private var theme
  @State private var pickerItem: PhotosPickerItem?
  @State private var showsCamera = false
  @State private var isReading = false
  @State private var result: LabelScanResult?
  @State private var message: String?
  @State private var prefill: FoodEntryPrefill?

  private var hasCamera: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: HeliosTokens.space(4)) {
        VStack(alignment: .leading, spacing: HeliosTokens.space(3)) {
          Text(
            "Photograph the Nutrition Facts panel flat and in good light. The text is read on this device."
          )
          .heliosFont(.callout)
          .foregroundStyle(theme.palette.text.secondary.color)
          .fixedSize(horizontal: false, vertical: true)
          if hasCamera {
            Button {
              showsCamera = true
            } label: {
              Label("Take Photo", systemImage: "camera").fixedSize(
                horizontal: false, vertical: true
              ).frame(maxWidth: .infinity)
            }
            .buttonStyle(.heliosPrimary)
            .accessibilityIdentifier("labelTakePhoto")
          }
          PhotosPicker(selection: $pickerItem, matching: .images) {
            Label("Choose Photo", systemImage: "photo.on.rectangle").fixedSize(
              horizontal: false, vertical: true
            ).frame(maxWidth: .infinity)
          }
          .buttonStyle(.heliosSecondary)
          .accessibilityIdentifier("labelChoosePhoto")
          #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--label-fixture") {
              Button("Use Sample Label") {
                result = LabelScan.result(lines: LabelScan.fixtureLines, locale: locale)
              }
              .buttonStyle(.heliosSecondary)
              .accessibilityIdentifier("labelUseSample")
            }
          #endif
        }
        .glassCard()

        if isReading { ProgressView("Reading the label…") }
        if let message {
          Text(message)
            .heliosFont(.callout)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("labelMessage")
        }
        if let result { resultCard(result) }
      }
      .padding()
    }
    .caliberScreen()
    .navigationTitle("Scan Label")
    .navigationBarTitleDisplayMode(.inline)
    .onChange(of: pickerItem) { _, item in
      guard let item else { return }
      Task { await read(item) }
    }
    .fullScreenCover(isPresented: $showsCamera) {
      CameraPhotoCapture { image in
        showsCamera = false
        if let image { Task { await read(image) } }
      }
      .ignoresSafeArea()
    }
    .sheet(item: $prefill) { prefill in
      AddFoodView(mealType: mealType, date: date, prefill: prefill)
    }
  }

  private func resultCard(_ result: LabelScanResult) -> some View {
    VStack(alignment: .leading, spacing: HeliosTokens.space(3)) {
      SectionHeader("Read from the label")
      if !result.prefill.servingDescription.isEmpty {
        Text("Per \(result.prefill.servingDescription)")
          .heliosFont(.footnote)
          .foregroundStyle(theme.palette.text.secondary.color)
      }
      row("Calories", result.prefill.calories, unit: "kcal", result)
      row("Protein", result.prefill.protein, unit: "g", result)
      row("Carbs", result.prefill.carbs, unit: "g", result)
      row("Fat", result.prefill.fat, unit: "g", result)
      ForEach(result.notes, id: \.self) { note in
        Label(note, systemImage: "exclamationmark.triangle.fill")
          .heliosFont(.footnote)
          .foregroundStyle(theme.palette.text.secondary.color)
          .fixedSize(horizontal: false, vertical: true)
      }
      Button {
        prefill = result.prefill
      } label: {
        Text("Use These Values").fixedSize(horizontal: false, vertical: true).frame(
          maxWidth: .infinity)
      }
      .buttonStyle(.heliosPrimary)
      .accessibilityIdentifier("labelUseValues")
      Text("You can name the food and correct any value on the next screen.")
        .heliosFont(.caption)
        .foregroundStyle(theme.palette.text.secondary.color)
        .fixedSize(horizontal: false, vertical: true)
    }
    .glassCard()
    .accessibilityIdentifier("labelResult")
  }

  private func row(_ title: String, _ value: String, unit: String, _ result: LabelScanResult)
    -> some View
  {
    HStack(alignment: .firstTextBaseline) {
      Text(title).heliosFont(.body)
      Spacer()
      if result.rowsToCheck.contains(title) {
        StatusBadge(.warning, "Check")
      }
      Text(value.isEmpty ? "Not read" : "\(value) \(unit)")
        .heliosFont(.bodyStrong)
        .foregroundStyle(
          value.isEmpty ? theme.palette.text.secondary.color : theme.palette.text.primary.color)
    }
    .accessibilityElement(children: .combine)
  }

  private func read(_ item: PhotosPickerItem) async {
    guard let data = try? await item.loadTransferable(type: Data.self),
      let image = UIImage(data: data)
    else {
      message = "That photo could not be opened. Try another."
      return
    }
    await read(image)
  }

  private func read(_ image: UIImage) async {
    guard let cgImage = image.cgImage else {
      message = "That photo could not be read. Try another."
      return
    }
    isReading = true
    message = nil
    defer { isReading = false }
    do {
      let lines = try await LabelScan.recognizeLines(in: cgImage)
      let scan = LabelScan.result(lines: lines, locale: locale)
      result = scan
      if !scan.isUsable {
        message =
          "Not enough of the label was read. Retake the photo straight on, or enter the values yourself."
      }
    } catch {
      message = "The label could not be read. Retake the photo or enter the values yourself."
    }
  }
}

extension FoodEntryPrefill: Identifiable {
  var id: String {
    [name, servingDescription, calories, protein, carbs, fat].joined(separator: "|")
  }
}

/// The system camera for a single still photo. Returns nil when the person cancels.
struct CameraPhotoCapture: UIViewControllerRepresentable {
  let onFinish: (UIImage?) -> Void

  func makeUIViewController(context: Context) -> UIImagePickerController {
    let picker = UIImagePickerController()
    picker.sourceType = .camera
    picker.delegate = context.coordinator
    return picker
  }

  func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

  func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

  final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate
  {
    let onFinish: (UIImage?) -> Void
    init(onFinish: @escaping (UIImage?) -> Void) { self.onFinish = onFinish }

    func imagePickerController(
      _ picker: UIImagePickerController,
      didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
      onFinish(info[.originalImage] as? UIImage)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { onFinish(nil) }
  }
}
