import CaliberCore
import CaliberDatabase
import CaliberSeedData
import Combine
import SwiftData
import SwiftUI

@MainActor
final class FoundationRuntime: ObservableObject {
  @Published var settings: FoundationSettings { didSet { persist() } }
  @Published private(set) var demo: DemoDataset?
  @Published private(set) var isLoadingDemo = false
  @Published var isDemoMode = false
  @Published var message: String?
  let account: HostedAccountModel
  let testing: Bool
  var preferenceStore: UserDefaults { defaults }
  private let defaults: UserDefaults
  private let directory: URL

  init() {
    #if DEBUG
      testing =
        ProcessInfo.processInfo.arguments.contains("--progress-ui-testing")
        || ProcessInfo.processInfo.arguments.contains("--foundation-ui-testing")
        || ProcessInfo.processInfo.arguments.contains("--account-ui-testing")
    #else
      testing = false
    #endif
    if testing {
      defaults = UserDefaults(suiteName: "Caliber.Foundation.UITests")!
      if ProcessInfo.processInfo.arguments.contains("--reset-foundation")
        || ProcessInfo.processInfo.arguments.contains("--progress-ui-testing")
      {
        defaults.removePersistentDomain(forName: "Caliber.Foundation.UITests")
      }
    } else {
      defaults = .standard
    }
    var loaded =
      defaults.data(forKey: "foundation.settings.v1").flatMap {
        try? JSONDecoder().decode(FoundationSettings.self, from: $0)
      } ?? FoundationSettings()
    if ProcessInfo.processInfo.arguments.contains("--progress-ui-testing") {
      loaded.ageConfirmed = true
      loaded.disclaimerAccepted = true
    }
    // Preserve the units that the current Progress screen already stores.
    if defaults.data(forKey: "foundation.settings.v1") == nil,
      let prior = defaults.string(forKey: "progressWeightUnit")
    {
      loaded.massUnit = prior == "kilograms" ? .kilograms : .pounds
    }
    settings = loaded
    account = HostedAccountModel.configured(testing: testing)
    let base =
      testing
      ? FileManager.default.temporaryDirectory.appendingPathComponent("CaliberUITestFoundation")
      : FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("CaliberFoundation")
    directory = base.appendingPathComponent("FictionalDemo-v1", isDirectory: true)
  }
  var colorScheme: ColorScheme? {
    switch settings.theme {
    case .system: nil
    case .light: .light
    case .dark, .oled: .dark
    }
  }
  private func persist() {
    if let data = try? JSONEncoder().encode(settings) {
      defaults.set(data, forKey: "foundation.settings.v1")
    }
    // The legacy screen reads this key. A unit preference never rewrites stored pounds.
    defaults.set(
      settings.massUnit == .kilograms ? "kilograms" : "pounds", forKey: "progressWeightUnit")
  }
  func showDemo() async {
    guard !isLoadingDemo else { return }
    if demo != nil {
      isDemoMode = true
      return
    }
    isLoadingDemo = true
    defer { isLoadingDemo = false }
    do {
      let directory = directory
      let dataset = try await Task.detached(priority: .userInitiated) {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var protected = directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try protected.setResourceValues(values)
        #if os(iOS)
          try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.complete], ofItemAtPath: directory.path)
        #endif
        let store = try FoundationStore(directory: directory)
        if let prior = try await store.loadDemo() { return prior }
        // Fixed endpoint keeps an interrupted two-store seed retry identical tomorrow.
        let ending = Date(timeIntervalSince1970: 1_791_331_200)
        let fixture = try DemoGenerator.make(yearEnding: ending)
        try await store.prepareDemo(fixture)
        guard let saved = try await store.loadDemo() else {
          throw FoundationStorageError.incompleteFixture
        }
        return saved
      }.value
      demo = dataset
      isDemoMode = true
    } catch {
      message =
        "The demo could not be opened. Your diary is unchanged. Try again after checking available storage."
    }
  }
}

/// Explicit startup recovery avoids a fatal crash or silently replacing a damaged store.
struct FoundationRootView: View {
  @EnvironmentObject private var runtime: FoundationRuntime
  @State private var container: ModelContainer?
  @State private var failed = false
  var body: some View {
    Group {
      if let container {
        if runtime.settings.ageConfirmed && runtime.settings.disclaimerAccepted {
          RootTabView().modelContainer(container)
        } else {
          AdultWelcomeView()
        }
      } else if failed {
        ContentUnavailableView {
          Label("Your data could not be opened", systemImage: "externaldrive.badge.exclamationmark")
        } description: {
          Text(
            "Your saved files have been kept. Restart the app or try again. The app will not erase your logs to recover."
          )
        } actions: {
          Button("Try Again", action: open)
        }
      } else {
        ProgressView("Opening Caliber…").task { open() }
      }
    }
    .environmentObject(runtime.account)
    .defaultAppStorage(runtime.preferenceStore)
    .preferredColorScheme(runtime.colorScheme)
    .environment(\.locale, Locale(identifier: runtime.settings.localeIdentifier))
    .environment(\.calendar, runtime.settings.calendar)
    .alert(
      "Could not complete action",
      isPresented: Binding(
        get: { runtime.message != nil }, set: { if !$0 { runtime.message = nil } })
    ) {
      Button("OK", role: .cancel) { runtime.message = nil }
    } message: {
      Text(runtime.message ?? "Please try again.")
    }
  }
  private func open() {
    failed = false
    do {
      let schema = Schema([
        FoodItem.self, Restaurant.self, MenuItem.self, MenuItemModifier.self,
        BuildableItemTemplate.self, BuildComponentCategory.self, BuildComponentOption.self,
        SavedMeal.self, SavedMealItem.self, DiaryEntry.self, WeightEntry.self, ProgressEntry.self,
        ProgressPhoto.self, Note.self, UserProfile.self,
      ])
      container = try ModelContainer(
        for: schema,
        configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: runtime.testing)])
    } catch { failed = true }
  }
}

private struct AdultWelcomeView: View {
  @EnvironmentObject private var runtime: FoundationRuntime
  @State private var adult = false
  @State private var understood = false
  var body: some View {
    NavigationStack {
      Form {
        Section {
          Text("One place for your daily logs").font(.title2.bold())
          Text(
            "Caliber helps you record and understand your information. It does not provide medical advice, diagnosis, or treatment. Consult a licensed clinician for medical decisions."
          )
        }
        Section {
          Toggle("I am 18 or older", isOn: $adult).accessibilityIdentifier("adultConfirmation")
          Toggle("I understand the app's scope", isOn: $understood).accessibilityIdentifier(
            "scopeConfirmation")
          Text("Only your confirmation is saved. A date of birth is not required.").font(.footnote)
        }
        Button("Continue") {
          runtime.settings.ageConfirmed = adult
          runtime.settings.disclaimerAccepted = understood
        }.disabled(!adult || !understood).frame(minHeight: 48).accessibilityIdentifier(
          "welcomeContinue")
      }.navigationTitle("Welcome to Caliber")
    }
  }
}
