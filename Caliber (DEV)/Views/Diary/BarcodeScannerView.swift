@preconcurrency import AVFoundation
import HeliosDesign
import SwiftUI
import UIKit

/// Present this view as a sheet. It returns one validated barcode for the
/// caller's food lookup; neither camera frames nor photos leave this screen.
struct BarcodeScannerView: View {
  @Environment(\.heliosTheme) private var theme
  @Environment(\.dismiss) private var dismiss
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.openURL) private var openURL
  @StateObject private var capture = BarcodeCaptureService()
  @State private var manualValue = ""
  @State private var validationMessage: String?
  @State private var didFinish = false
  @FocusState private var isEditingManualCode: Bool

  let onScanned: (String) -> Void

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          VStack(alignment: .leading, spacing: 12) { cameraArea }
            .glassCard()

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
      .toolbar {
        ToolbarItemGroup(placement: .keyboard) {
          Spacer()
          Button("Done") { isEditingManualCode = false }
            .frame(minWidth: 48, minHeight: 48)
        }
      }
      .safeAreaInset(edge: .bottom) {
        Button(action: cancel) {
          Text("Cancel").font(.body).frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(.heliosSecondary)
        .accessibilityIdentifier("barcodeCancel")
        .padding(.horizontal).padding(.vertical, 8)
        .background { CaliberRowBackground() }
      }
      .onAppear { capture.start() }
      .onDisappear {
        didFinish = true
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
          .frame(height: 360)
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
      cameraPlaceholder
      Label(message, systemImage: "camera.fill")
        .foregroundStyle(.secondary)
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

  /// The look book's camera frame when there is no live preview.
  private var cameraPlaceholder: some View {
    RoundedRectangle(cornerRadius: HeliosTokens.radius.card, style: .continuous)
      .fill(Color.black.opacity(0.55))
      .frame(height: 200)
      .overlay { ViewfinderBrackets().padding(28) }
      .overlay {
        Image(systemName: "barcode.viewfinder")
          .resizable().scaledToFit().frame(width: 56, height: 56)
          .foregroundStyle(.white.opacity(0.6))
      }
      .accessibilityHidden(true)
  }

  private func complete(with rawValue: String) {
    guard !didFinish else { return }
    do {
      let code = try BarcodeValue.normalize(rawValue)
      // Both the camera and the manual button reach this gate. Stop the
      // camera before the callback so a second frame cannot log twice.
      didFinish = true
      capture.stop()
      onScanned(code)
      dismiss()
    } catch {
      validationMessage = error.localizedDescription
    }
  }

  private func cancel() {
    didFinish = true
    capture.stop()
    dismiss()
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
