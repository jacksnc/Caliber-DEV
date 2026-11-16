@preconcurrency import AVFoundation
import HeliosDesign
import SwiftUI
import UIKit

/// Present this view full screen, as the look book draws it. With a coordinator the barcode is
/// looked up here and the product opens as a sheet over the camera; otherwise, or when nothing
/// is found, it returns the validated barcode for the caller's own lookup. Neither camera
/// frames nor photos leave this screen.
struct BarcodeScannerView: View {
  @Environment(\.heliosTheme) private var theme
  @Environment(\.dismiss) private var dismiss
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.openURL) private var openURL
  @StateObject private var capture = BarcodeCaptureService()
  @State private var manualValue = ""
  @State private var validationMessage: String?
  @State private var didFinish = false
  /// The product a code found, shown as a sheet over the camera.
  @State private var scanned: ScannedProduct?
  @State private var isLookingUp = false
  /// Set once this screen has used the coordinator, so closing it can clear its own result
  /// and nothing the caller had before.
  @State private var usedLookup = false
  @State private var lookupTask: Task<Void, Never>?
  @FocusState private var isEditingManualCode: Bool

  let onScanned: (String) -> Void
  /// Look book: the camera's mode switcher. Picking another mode closes this camera and the
  /// caller opens that tool. Nil hides the switcher.
  var onSwitchMode: ((FoodCaptureMode) -> Void)?
  /// Look book: the lookup that lets the product open over the camera. Nil hands every code
  /// straight back through `onScanned`.
  var coordinator: BarcodeLookupCoordinator?
  /// Only names the meal on the sheet's button; the caller owns where the food is saved.
  var mealType = MealType.snack
  /// Called with the amount chosen on the sheet. The caller opens its editable review after
  /// this camera has closed; nothing is saved from the camera.
  var onReview: ((ScannedPortion?) -> Void)?

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          // Look book: the camera fills the top, with a close button over it instead of a bar.
          // One layout at every text size: a layout that changes with the size is rebuilt
          // while the accessibility audit measures it.
          topBar
          VStack(alignment: .leading, spacing: 12) { cameraArea }
            .overlay(alignment: .top) { scanStatus }

          VStack(alignment: .leading, spacing: 8) {
            Text("Enter Barcode")
              .font(.headline)
            Text(
              "Type the numbers below the barcode, including any leading zeroes. Use 8, 12, 13, or 14 digits."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
            TextField(
              "Digits", text: $manualValue,
              prompt: Text("Digits").foregroundStyle(theme.palette.text.secondary.color)
            )
            .keyboardType(.numberPad)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .font(.title3.monospacedDigit())
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(minHeight: 48)
            .background(theme.palette.opaque.raised.color, in: RoundedRectangle(cornerRadius: 10))
            .overlay {
              RoundedRectangle(cornerRadius: 10)
                .strokeBorder(theme.palette.border.strong.color, lineWidth: 1)
            }
            .focused($isEditingManualCode)
            .accessibilityLabel("Barcode digits")
            .accessibilityIdentifier("barcodeManualInput")
            .onChange(of: manualValue) { _, _ in validationMessage = nil }

            if let validationMessage {
              Text(validationMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("barcodeValidationMessage")
            }

            Button {
              complete(with: manualValue)
            } label: {
              Text("Find Food")
                .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.heliosPrimary)
            .disabled(
              manualValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || didFinish
                || isLookingUp
            )
            .accessibilityIdentifier("barcodeConfirm")

            Text(
              "Supports EAN-8, UPC-A, EAN-13, and GTIN-14. Compressed UPC-E barcodes aren't supported."
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
          }
          .glassCard()
        }
        .padding()
      }
      .caliberScreen()
      .scrollDismissesKeyboard(.interactively)
      .navigationTitle("Scan Barcode")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar(.hidden, for: .navigationBar)
      .toolbar {
        ToolbarItemGroup(placement: .keyboard) {
          Spacer()
          Button("Done") { isEditingManualCode = false }
            .frame(minWidth: 48, minHeight: 48)
        }
      }
      .sheet(item: $scanned, onDismiss: resumeScanning) { item in
        ScannedProductSheet(product: item.product, mealType: mealType) { portion in
          openReview(portion)
        }
      }
      .onAppear { capture.start() }
      .onDisappear {
        lookupTask?.cancel()
        // A sheet over this screen is not leaving it.
        if scanned == nil { didFinish = true }
        capture.stop()
      }
      .onChange(of: capture.scannedValue) { _, value in
        if let value { complete(with: value) }
      }
      .onChange(of: isEditingManualCode) { _, isEditing in
        if isEditing {
          capture.stop()
        } else if scenePhase == .active && !didFinish {
          capture.start()
        }
      }
      .onChange(of: scenePhase) { _, phase in
        if phase == .active && !didFinish && !isEditingManualCode {
          capture.start()
        } else {
          capture.stop()
        }
      }
    }
  }

  @ViewBuilder
  private var cameraArea: some View {
    switch capture.status {
    case .scanning:
      if let session = capture.previewSession {
        BarcodeCameraPreview(session: session)
          .frame(height: 420)
          .overlay { ViewfinderBrackets().padding(28).accessibilityHidden(true) }
          .clipShape(RoundedRectangle(cornerRadius: HeliosTokens.radius.card, style: .continuous))
          .accessibilityLabel("Live barcode camera preview")
          .accessibilityIdentifier("barcodeCameraPreview")
      }
      Label("Hold the barcode inside the frame", systemImage: "barcode.viewfinder")
        .font(.subheadline)
        .foregroundStyle(.secondary)
    case .requestingPermission:
      ProgressView("Waiting for camera permission…")
        .frame(maxWidth: .infinity, minHeight: 120)
    case .denied:
      Label(
        "Camera access is off. Enter a barcode below, or enable Camera in Settings.",
        systemImage: "camera.fill"
      )
      .foregroundStyle(.secondary)
      Button {
        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
      } label: {
        Text("Open Settings").frame(maxWidth: .infinity, minHeight: 48)
      }
      .buttonStyle(.heliosSecondary)
    case .unavailable(let message):
      // Decorative; the scroll view leaves room for the message and actions below it.
      cameraPlaceholder
      Label(message, systemImage: "camera.fill")
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("barcodeCameraUnavailable")
      Button {
        capture.retry()
      } label: {
        Text("Retry Camera").frame(maxWidth: .infinity, minHeight: 48)
      }
      .buttonStyle(.heliosSecondary)
    case .idle:
      Label(
        isEditingManualCode
          ? "Camera paused while you enter a barcode."
          : "Preparing the camera. You can also enter a barcode below.",
        systemImage: "barcode.viewfinder"
      )
      .foregroundStyle(.secondary)
    }
  }

  private var topBar: some View {
    VStack(alignment: .leading, spacing: 12) {
      // Words never break mid-word: the title moves under the close button when it would.
      ViewThatFits(in: .horizontal) {
        HStack(spacing: 12) {
          closeButton
          title.fixedSize()
        }
        VStack(alignment: .leading, spacing: 8) {
          closeButton
          title
        }
      }
      if let onSwitchMode { modePicker(onSwitchMode) }
    }
  }

  private var closeButton: some View {
    Button(action: cancel) {
      Image(systemName: "xmark")
        .font(.body.weight(.semibold))
        .foregroundStyle(theme.palette.text.primary.color)
        .frame(width: 48, height: 48)
        .background { GlassBackground(level: .raised, cornerRadius: 24) }
        .contentShape(Circle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Cancel")
    .accessibilityIdentifier("barcodeCancel")
  }

  private var title: some View {
    Text("Scan barcode").heliosFont(.section)
      .accessibilityAddTraits(.isHeader)
      .fixedSize(horizontal: false, vertical: true)
      .frame(minHeight: 48, alignment: .leading)
  }

  /// The look book's segmented modes. When the words do not fit in one row they move to two
  /// rows, then to one per row, so a mode name is never split or cut off.
  private func modePicker(_ onSwitchMode: @escaping (FoodCaptureMode) -> Void) -> some View {
    let modes = FoodCaptureMode.allCases
    return ViewThatFits(in: .horizontal) {
      HStack(spacing: 2) {
        ForEach(modes) { modeButton($0, onSwitchMode).fixedSize() }
      }
      Grid(horizontalSpacing: 2, verticalSpacing: 2) {
        GridRow {
          ForEach(modes.prefix(2)) { modeButton($0, onSwitchMode).fixedSize() }
        }
        GridRow {
          ForEach(modes.suffix(2)) { modeButton($0, onSwitchMode).fixedSize() }
        }
      }
      VStack(spacing: 2) {
        ForEach(modes) { modeButton($0, onSwitchMode) }
      }
    }
    .padding(4)
    .frame(maxWidth: .infinity)
    .background { GlassBackground(level: .raised, cornerRadius: 24) }
  }

  private func modeButton(
    _ mode: FoodCaptureMode, _ onSwitchMode: @escaping (FoodCaptureMode) -> Void
  ) -> some View {
    Button {
      guard mode != .barcode else { return }
      didFinish = true
      lookupTask?.cancel()
      capture.stop()
      onSwitchMode(mode)
      dismiss()
    } label: {
      Text(mode.title)
        .heliosFont(.footnote)
        .multilineTextAlignment(.center)
        .padding(.horizontal, HeliosTokens.space(3))
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 44)
        .foregroundStyle(
          mode == .barcode ? theme.palette.accent.base.color : theme.palette.text.primary.color
        )
        .background {
          if mode == .barcode {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
              .fill(theme.palette.accent.subtle.color)
          }
        }
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(mode == .barcode ? [.isSelected] : [])
    .accessibilityIdentifier("captureMode-\(mode.rawValue)")
  }

  /// The look book's camera frame when there is no live preview.
  private var cameraPlaceholder: some View {
    RoundedRectangle(cornerRadius: HeliosTokens.radius.card, style: .continuous)
      .fill(Color.black.opacity(0.55))
      .frame(height: 300)
      .overlay { ViewfinderBrackets().padding(28) }
      .overlay {
        Image(systemName: "barcode.viewfinder")
          .resizable().scaledToFit().frame(width: 56, height: 56)
          .foregroundStyle(.white.opacity(0.6))
      }
      .accessibilityHidden(true)
  }

  /// Both the camera and the manual button reach this gate.
  private func complete(with rawValue: String) {
    guard !didFinish, !isLookingUp, scanned == nil else { return }
    let code: String
    do {
      code = try BarcodeValue.normalize(rawValue)
    } catch {
      validationMessage = error.localizedDescription
      return
    }
    guard let coordinator else {
      handOff(code)
      return
    }
    isEditingManualCode = false
    isLookingUp = true
    usedLookup = true
    lookupTask = Task { @MainActor in
      await coordinator.lookup(code)
      isLookingUp = false
      guard !Task.isCancelled, !didFinish else { return }
      if let product = coordinator.product {
        scanned = ScannedProduct(product: product)
      } else {
        // Nothing to show yet (not found, offline, or online lookup not allowed): the
        // caller's lookup screen has the permission switch and says why.
        handOff(code)
      }
    }
  }

  /// Returns the code to the caller's own lookup, as the camera always did.
  private func handOff(_ code: String) {
    // Stop the camera before the callback so a second frame cannot log twice.
    didFinish = true
    capture.stop()
    onScanned(code)
    dismiss()
  }

  /// The sheet's one action. The caller opens its editable review once this camera is gone.
  private func openReview(_ portion: ScannedPortion?) {
    didFinish = true
    onReview?(portion)
    scanned = nil
    capture.stop()
    dismiss()
  }

  /// The sheet was swiped away: forget its product and read the next barcode.
  private func resumeScanning() {
    guard !didFinish else { return }
    if usedLookup { coordinator?.cancel() }
    usedLookup = false
    capture.retry()
  }

  private func cancel() {
    didFinish = true
    lookupTask?.cancel()
    if usedLookup { coordinator?.cancel() }
    capture.stop()
    dismiss()
  }

  /// Look book: the status that sits over the camera, "Barcode read" while the product sheet is up.
  @ViewBuilder private var scanStatus: some View {
    if isLookingUp {
      statusPill {
        Label {
          Text("Looking up food…")
        } icon: {
          ProgressView().controlSize(.small)
        }
      }
      .accessibilityIdentifier("barcodeLooking")
    } else if scanned != nil {
      statusPill { StatusBadge(.success, "Barcode read") }
        .accessibilityIdentifier("barcodeRead")
    }
  }

  private func statusPill<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
    content()
      .heliosFont(.footnote)
      .fixedSize(horizontal: false, vertical: true)
      .padding(.horizontal, HeliosTokens.space(3))
      .padding(.vertical, HeliosTokens.space(2))
      .background { GlassBackground(level: .overlay, cornerRadius: 20) }
      .padding(.top, HeliosTokens.space(3))
      .frame(maxWidth: .infinity)
  }
}

private struct BarcodeCameraPreview: UIViewRepresentable {
  let session: AVCaptureSession

  func makeUIView(context: Context) -> BarcodePreviewUIView {
    let view = BarcodePreviewUIView()
    view.previewLayer.videoGravity = .resizeAspectFill
    view.previewLayer.session = session
    return view
  }

  func updateUIView(_ view: BarcodePreviewUIView, context: Context) {
    if view.previewLayer.session !== session { view.previewLayer.session = session }
    view.setNeedsLayout()
  }

  static func dismantleUIView(_ view: BarcodePreviewUIView, coordinator: ()) {
    view.previewLayer.session = nil
  }
}

private final class BarcodePreviewUIView: UIView {
  override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
  var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

  override func layoutSubviews() {
    super.layoutSubviews()
    guard let connection = previewLayer.connection,
      let orientation = window?.windowScene?.interfaceOrientation
    else { return }
    let angle: CGFloat
    switch orientation {
    case .portrait: angle = 90
    case .portraitUpsideDown: angle = 270
    case .landscapeLeft: angle = 180
    case .landscapeRight: angle = 0
    default: return
    }
    if connection.isVideoRotationAngleSupported(angle) {
      connection.videoRotationAngle = angle
    }
  }
}

/// Four white corner marks around the scan area. White on video in both themes
/// (DESIGN.md: camera screens are the exception to theming).
private struct ViewfinderBrackets: View {
  var body: some View {
    GeometryReader { proxy in
      let size = proxy.size
      let arm = min(size.width, size.height) * 0.16
      Path { path in
        for (x, y, dx, dy) in [
          (0.0, 0.0, 1.0, 1.0), (size.width, 0.0, -1.0, 1.0),
          (0.0, size.height, 1.0, -1.0), (size.width, size.height, -1.0, -1.0),
        ] {
          path.move(to: CGPoint(x: x + dx * arm, y: y))
          path.addLine(to: CGPoint(x: x, y: y))
          path.addLine(to: CGPoint(x: x, y: y + dy * arm))
        }
      }
      .stroke(.white, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
    }
  }
}

/// The look book's capture modes on the camera screen.
enum FoodCaptureMode: String, CaseIterable, Identifiable {
  case barcode, label, photo, search
  var id: String { rawValue }
  var title: LocalizedStringKey {
    switch self {
    case .barcode: "Barcode"
    case .label: "Label"
    case .photo: "Photo"
    case .search: "Search"
    }
  }
}
