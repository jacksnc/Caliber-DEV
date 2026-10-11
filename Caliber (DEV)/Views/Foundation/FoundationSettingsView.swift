import CaliberCore
import SwiftUI

struct FoundationSettingsView: View {
  @EnvironmentObject private var runtime: FoundationRuntime
  private static var thirdPartyNotices: String {
    guard let url = Bundle.main.url(forResource: "ThirdPartyNotices", withExtension: "txt"),
      let text = try? String(contentsOf: url, encoding: .utf8)
    else { return "Notices could not be loaded. Please reopen the app." }
    return text
  }
  var body: some View {
    Form {
      Section("Appearance and Privacy") {
        Picker("Theme", selection: $runtime.settings.theme) {
          Text("System").tag(AppTheme.system)
          Text("Light").tag(AppTheme.light)
          Text("Dark").tag(AppTheme.dark)
          Text("OLED Black").tag(AppTheme.oled)
        }
        Toggle("Hide Calories and Weight", isOn: $runtime.settings.hideNumbers)
          .accessibilityIdentifier("hideNumbers")
        Text(
          "Number-free mode keeps photos and notes available and hides numerical editors, charts, and their accessibility labels."
        ).font(.footnote)
      }
      Section("Units") {
        Picker("Weight", selection: $runtime.settings.massUnit) {
          ForEach(MassUnit.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }
        .accessibilityIdentifier("settingsWeightUnit")
        Picker("Length", selection: $runtime.settings.distanceUnit) {
          ForEach(DistanceUnit.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }
        Picker("Energy", selection: $runtime.settings.energyUnit) {
          ForEach(EnergyUnit.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }
        Picker("Volume", selection: $runtime.settings.volumeUnit) {
          ForEach(VolumeUnit.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }
        Picker("Temperature", selection: $runtime.settings.temperatureUnit) {
          ForEach(TemperatureUnit.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }
        Text(
          "Weight applies to Progress; energy applies to Today. Original diary entries retain their labeled calorie units. Other preferences are saved for the modules that use them."
        ).font(.footnote)
      }
      Section("Formatting") {
        Picker("Week Starts", selection: $runtime.settings.weekStart) {
          Text("Monday").tag(WeekStart.monday)
          Text("Sunday").tag(WeekStart.sunday)
          Text("Saturday").tag(WeekStart.saturday)
        }
        Picker("Number and Date Format", selection: $runtime.settings.localeIdentifier) {
          Text("Device Format").tag(Locale.current.identifier)
          if Locale.current.identifier != "en_US" { Text("English (United States)").tag("en_US") }
          if Locale.current.identifier != "en_GB" {
            Text("English (United Kingdom)").tag("en_GB")
          }
          if Locale.current.identifier != "fr_FR" { Text("French (France)").tag("fr_FR") }
          if Locale.current.identifier != "de_DE" { Text("German (Germany)").tag("de_DE") }
        }
        .accessibilityIdentifier("settingsNumberFormat")
        Text(
          "Interface language is English. These settings change formatting, not the entered values."
        ).font(.footnote)
      }
      Section("Demo") {
        Button("Explore Demo") { Task { await runtime.showDemo() } }.disabled(
          runtime.isLoadingDemo
        ).frame(minHeight: 48)
      }
      Section("Storage and Sync") {
        Label("Your logs are on this device", systemImage: "iphone")
        NavigationLink {
          HostedAccountView()
        } label: {
          Text("Account").frame(minHeight: 48)
        }.accessibilityIdentifier("openAccount")
        Text("Cloud backup is not active. No diary, photo, or health value is uploaded.").font(
          .footnote)
        Text(
          "Existing logs continue using their original store. Foundation migration tests run on separate copies."
        ).font(.footnote)
      }
      Section("About") {
        NavigationLink {
          ScrollView {
            Text(Self.thirdPartyNotices).font(.footnote).textSelection(.enabled).padding()
          }.navigationTitle("Open-source Notices")
        } label: {
          Text("Open-source Notices").frame(minHeight: 48)
        }
        Text(
          "Caliber is a logging and education tool, not medical advice, diagnosis, or treatment. Consult a licensed clinician for medical decisions."
        )
        Text(
          "Stack is disabled. Advanced feature flags remain off until their implementations and release checks pass."
        ).font(.footnote)
      }
    }.navigationTitle("Settings")
  }
}
