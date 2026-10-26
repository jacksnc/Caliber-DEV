import Combine
import Foundation
import HeliosDesign
import LocalAuthentication
import SwiftData
import SwiftUI

/// Whether this build and configuration may offer Stack at all (brief §5.1, §11.3).
enum StackFeature {
  /// Build-time omission: add `CALIBER_OMIT_STACK` to Active Compilation Conditions to
  /// produce a build without the module's routes.
  static var isCompiledIn: Bool {
    #if CALIBER_OMIT_STACK
      false
    #else
      true
    #endif
  }

  /// Region or store kill switch. No hosted flag service is active (AGENTS.md), so this
  /// reads a local configuration key that a future reviewed flag source can set.
  static func isAllowed(defaults: UserDefaults) -> Bool {
    isCompiledIn && !defaults.bool(forKey: "stack.disabledByConfiguration")
  }
}

/// The person's Stack choices and the module's private store. Opting in records only which
/// scope text was accepted and when; no Stack values live in preferences.
@MainActor
final class StackRuntime: ObservableObject {
  static let scopeVersion = "stack-scope-v1"
  @Published private(set) var isEnabled: Bool
  @Published var requiresUnlock: Bool {
    didSet { defaults.set(requiresUnlock, forKey: Self.unlockKey) }
  }
  /// STK-10 is a P1 feature behind `feature.stk-10`, off by default
  /// (architecture/feature-flags.json).
  @Published var showsEstimate: Bool {
    didSet { defaults.set(showsEstimate, forKey: Self.estimateKey) }
  }
  @Published private(set) var container: ModelContainer?
  @Published private(set) var failedToOpen = false
  let isAllowed: Bool
  let testing: Bool
  private let defaults: UserDefaults
  private static let scopeKey = "stack.scope.version"
  private static let scopeDateKey = "stack.scope.date"
  private static let enabledKey = "stack.enabled"
  private static let unlockKey = "stack.requiresUnlock"
  private static let estimateKey = "feature.stk-10"

  init(defaults: UserDefaults, testing: Bool) {
    self.defaults = defaults
    self.testing = testing
    isAllowed = StackFeature.isAllowed(defaults: defaults)
    var enabled =
      isAllowed && defaults.bool(forKey: Self.enabledKey)
      && defaults.string(forKey: Self.scopeKey) == Self.scopeVersion
    // Simulators cannot answer the passcode prompt, so isolated UI tests start unlocked.
    var unlock = defaults.object(forKey: Self.unlockKey) as? Bool ?? !testing
    var estimate = defaults.bool(forKey: Self.estimateKey)
    #if DEBUG
      // Screenshot tests open Stack with fictional entries and no lock.
      if testing && ProcessInfo.processInfo.arguments.contains("--stack-fixture") {
        enabled = isAllowed
        unlock = false
        estimate = true
      }
    #endif
    isEnabled = enabled
    requiresUnlock = unlock
    showsEstimate = estimate
  }

  /// Turns Stack on after the person accepts the scope statement.
  func enable() {
    guard isAllowed else { return }
    defaults.set(Self.scopeVersion, forKey: Self.scopeKey)
    defaults.set(Date(), forKey: Self.scopeDateKey)
    defaults.set(true, forKey: Self.enabledKey)
    isEnabled = true
  }

  /// Hides Stack. Its private store is kept until the person deletes it.
  func disable() {
    defaults.set(false, forKey: Self.enabledKey)
    isEnabled = false
  }

  /// Opens the private store the first time Stack is shown.
  func open() {
    guard container == nil, isEnabled else { return }
    do {
      let opened = try StackStore.container(inMemory: testing)
      #if DEBUG
        if testing && ProcessInfo.processInfo.arguments.contains("--stack-fixture") {
          StackFixture.seed(in: opened.mainContext, now: .now, calendar: .current)
        }
      #endif
      container = opened
      failedToOpen = false
    } catch {
      failedToOpen = true
    }
  }

  /// Works whether or not Stack is turned on, so hidden data can still be erased.
  func deleteAllData() throws {
    if container == nil { container = try StackStore.container(inMemory: testing) }
    guard let container else { return }
    try StackStore.deleteAll(in: container.mainContext)
  }
}

/// Stack data lives in its own SwiftData store, separate from the diary (D04), with
/// complete file protection and no device backup (§5.1.3: no health data in iCloud).
enum StackStore {
  static let schema = Schema([StackCompound.self, StackDose.self])

  static func container(inMemory: Bool) throws -> ModelContainer {
    if inMemory {
      return try ModelContainer(
        for: schema,
        configurations: [ModelConfiguration("Stack", schema: schema, isStoredInMemoryOnly: true)])
    }
    var directory = FileManager.default.urls(
      for: .applicationSupportDirectory, in: .userDomainMask)[
        0
      ]
      .appendingPathComponent("CaliberStack", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try directory.setResourceValues(values)
    try FileManager.default.setAttributes(
      [.protectionKey: FileProtectionType.complete], ofItemAtPath: directory.path)
    let url = directory.appendingPathComponent("Stack.store")
    return try ModelContainer(
      for: schema, configurations: [ModelConfiguration("Stack", schema: schema, url: url)])
  }

  /// Deletes every Stack entry. Used by "Delete Stack Data" in Settings.
  @MainActor static func deleteAll(in context: ModelContext) throws {
    try context.delete(model: StackDose.self)
    try context.delete(model: StackCompound.self)
    try context.save()
  }
}

/// Asks for Face ID, Touch ID or the device passcode before Stack is shown (STK-20, D19),
/// and covers Stack whenever the app is not active so it never appears in the app switcher.
struct StackLockGate<Content: View>: View {
  let requiresUnlock: Bool
  @ViewBuilder let content: () -> Content
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.heliosTheme) private var theme
  @State private var isUnlocked = false
  @State private var message: String?

  var body: some View {
    ZStack {
      if !requiresUnlock || isUnlocked {
        content()
      } else {
        locked
      }
      if scenePhase != .active {
        CaliberCanvas().ignoresSafeArea()
      }
    }
    .onChange(of: scenePhase) { _, phase in
      if phase == .background { isUnlocked = false }
    }
  }

  private var locked: some View {
    VStack(spacing: HeliosTokens.space(4)) {
      Image(systemName: "lock.fill")
        .font(.largeTitle)
        .foregroundStyle(theme.palette.accent.base.color)
        .accessibilityHidden(true)
      Text("Stack is locked").heliosFont(.title)
      Text("Unlock to see your doses. Stack stays private on this device.")
        .heliosFont(.callout)
        .foregroundStyle(theme.palette.text.secondary.color)
        .multilineTextAlignment(.center)
      if let message {
        Text(message).heliosFont(.footnote)
          .foregroundStyle(theme.palette.text.secondary.color)
          .multilineTextAlignment(.center)
      }
      Button("Unlock", action: unlock)
        .buttonStyle(.heliosPrimary)
        .accessibilityIdentifier("stackUnlock")
    }
    .padding(HeliosTokens.space(6))
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background { CaliberCanvas() }
    .task { unlock() }
  }

  private func unlock() {
    let context = LAContext()
    var error: NSError?
    guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
      // Without a passcode the device cannot protect anything; say so rather than
      // pretending the lock works.
      message =
        "Set a device passcode in Settings to lock Stack. Until then it opens without a lock."
      isUnlocked = true
      return
    }
    context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock Stack") {
      success, _ in
      Task { @MainActor in
        isUnlocked = success
        if !success { message = "Stack stays locked. Try again when you are ready." }
      }
    }
  }
}
