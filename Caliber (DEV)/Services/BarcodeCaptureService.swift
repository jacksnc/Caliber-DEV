@preconcurrency import AVFoundation
import Combine
import Foundation

/// UI state stays on the main actor. The controller below owns all camera
/// configuration and start/stop calls on its dedicated serial queue.
@MainActor
final class BarcodeCaptureService: ObservableObject {
  enum Status: Equatable {
    case idle
    case requestingPermission
    case scanning
    case denied
    case unavailable(String)
  }

  @Published private(set) var status: Status = .idle
  @Published private(set) var scannedValue: String?
  private var controller: BarcodeSessionController?
  private var authorizationTask: Task<Void, Never>?
  private var activationID = UUID()
  private var isActive = false

  var previewSession: AVCaptureSession? { controller?.session }

  init() {
    controller = BarcodeSessionController { [weak self] event in
      Task { @MainActor [weak self] in
        guard let self, self.isActive else { return }
        switch event {
        case .started:
          self.status = .scanning
        case .unavailable(let message):
          self.status = .unavailable(message)
        case .scanned(let code):
          self.scannedValue = code
        }
      }
    }
  }

  func start() {
    guard !isActive else { return }
    isActive = true
    activationID = UUID()
    let requestID = activationID
    scannedValue = nil

    guard AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil
    else {
      status = .unavailable("No camera is available. You can enter the barcode below.")
      return
    }
    // iOS terminates an app that requests camera access without this key.
    // Manual entry remains usable while a development build is configured.
    guard
      let usage = Bundle.main.object(forInfoDictionaryKey: "NSCameraUsageDescription") as? String,
      !usage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else {
      status = .unavailable(
        "Camera scanning isn't available in this build. You can enter the barcode below.")
      return
    }

    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:
      controller?.start()
    case .notDetermined:
      status = .requestingPermission
      authorizationTask = Task { [weak self] in
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        guard let self, !Task.isCancelled, self.isActive,
          self.activationID == requestID
        else { return }
        if granted {
          self.controller?.start()
        } else {
          self.status = .denied
        }
      }
    case .denied, .restricted:
      status = .denied
    @unknown default:
      status = .unavailable("The camera couldn't be opened. You can enter the barcode below.")
    }
  }

  func stop() {
    isActive = false
    activationID = UUID()
    authorizationTask?.cancel()
    authorizationTask = nil
    controller?.stop()
    status = .idle
  }

  func retry() {
    stop()
    start()
  }
}

private nonisolated enum BarcodeCaptureEvent: Sendable {
  case started
  case scanned(String)
  case unavailable(String)
}

/// @unchecked Sendable is limited to this queue-confined AVFoundation owner.
/// Only preview-layer attachment reads `session` on the main thread; mutable
/// controller state and camera lifecycle are accessed on `sessionQueue`.
private nonisolated final class BarcodeSessionController: NSObject, @unchecked Sendable {
  let session = AVCaptureSession()
  private let sessionQueue = DispatchQueue(label: "Caliber.BarcodeCamera.session")
  private let metadataQueue = DispatchQueue(label: "Caliber.BarcodeCamera.metadata")
  private let onEvent: @Sendable (BarcodeCaptureEvent) -> Void
  private var isConfigured = false
  private var wantsRunning = false
  private var didDeliver = false
  private var observers: [NSObjectProtocol] = []

  init(onEvent: @escaping @Sendable (BarcodeCaptureEvent) -> Void) {
    self.onEvent = onEvent
    super.init()
    for name in [Notification.Name.AVCaptureSessionRuntimeError, .AVCaptureSessionWasInterrupted] {
      observers.append(
        NotificationCenter.default.addObserver(forName: name, object: session, queue: nil) {
          [weak self] _ in
          self?.cameraInterrupted()
        })
    }
  }

  deinit {
    observers.forEach(NotificationCenter.default.removeObserver)
  }

  func start() {
    sessionQueue.async { [self] in
      wantsRunning = true
      didDeliver = false
      do {
        if !isConfigured { try configure() }
        guard wantsRunning else { return }
        if !session.isRunning { session.startRunning() }
        if session.isRunning {
          onEvent(.started)
        } else {
          onEvent(
            .unavailable("The camera couldn't start. You can retry or enter the barcode below."))
        }
      } catch {
        onEvent(
          .unavailable("The camera couldn't start. You can retry or enter the barcode below."))
      }
    }
  }

  func stop() {
    sessionQueue.async { [self] in
      wantsRunning = false
      if session.isRunning { session.stopRunning() }
    }
  }

  private func configure() throws {
    guard
      let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
    else {
      throw CaptureError.unavailable
    }
    let input = try AVCaptureDeviceInput(device: camera)
    let output = AVCaptureMetadataOutput()
    session.beginConfiguration()
    defer { session.commitConfiguration() }
    // A previous partial configuration may have failed. Retry starts clean.
    session.inputs.forEach(session.removeInput)
    session.outputs.forEach(session.removeOutput)
    session.sessionPreset = .high
    guard session.canAddInput(input) else { throw CaptureError.unavailable }
    session.addInput(input)
    guard session.canAddOutput(output) else { throw CaptureError.unavailable }
    session.addOutput(output)
    output.setMetadataObjectsDelegate(self, queue: metadataQueue)
    // UPC-A is delivered as EAN-13 with an initial zero. UPC-E is omitted:
    // compressed UPC-E digits must not be mistaken for EAN-8/GTIN-8.
    let supported: [AVMetadataObject.ObjectType] = [.ean8, .ean13, .itf14]
    let available = supported.filter { output.availableMetadataObjectTypes.contains($0) }
    guard !available.isEmpty else { throw CaptureError.unavailable }
    output.metadataObjectTypes = available
    isConfigured = true
  }

  private func cameraInterrupted() {
    sessionQueue.async { [self] in
      guard wantsRunning else { return }
      wantsRunning = false
      if session.isRunning { session.stopRunning() }
      onEvent(
        .unavailable("Camera scanning was interrupted. You can retry or enter the barcode below."))
    }
  }

  private enum CaptureError: Error { case unavailable }
}

extension BarcodeSessionController: AVCaptureMetadataOutputObjectsDelegate {
  func metadataOutput(
    _ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject],
    from connection: AVCaptureConnection
  ) {
    let codes = metadataObjects.compactMap { object -> String? in
      guard let value = (object as? AVMetadataMachineReadableCodeObject)?.stringValue else {
        return nil
      }
      return try? BarcodeValue.normalize(value)
    }
    guard let code = codes.first else { return }
    // Return from the metadata callback before stopping the session, so
    // shutdown never waits on this callback's own delivery queue.
    sessionQueue.async { [self] in
      guard wantsRunning, !didDeliver else { return }
      didDeliver = true
      wantsRunning = false
      if session.isRunning { session.stopRunning() }
      onEvent(.scanned(code))
    }
  }
}
