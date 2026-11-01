import CaliberCore
import SwiftUI

struct SeasonalAppearanceSettingsSection: View {
  @Environment(\.seasonalAppearance) private var season
  @AppStorage("appearance.christmas.snowMotion.v1") private var motionEnabled = true

  var body: some View {
    Section("Seasonal Appearance") {
      Label(
        season == .christmas ? "Christmas appearance is active" : "Christmas begins December 1",
        systemImage: season == .christmas ? "snowflake" : "lock"
      )
      .accessibilityIdentifier("seasonalAppearanceStatus")
      Text(
        "Christmas appears automatically December 1–31 using your iPhone's local date. Your normal appearance returns January 1."
      )
      .font(.footnote)
      if season == .christmas {
        Image("HeliosChristmasMark")
          .resizable().scaledToFit().frame(maxWidth: .infinity, maxHeight: 144)
          .accessibilityLabel("Helios Christmas infinity logo with a snowflake")
        Toggle("Snowfall Motion", isOn: $motionEnabled)
          .accessibilityIdentifier("seasonalSnowMotion")
        Text(
          "Reduce Motion, Reduce Transparency, Increase Contrast and Low Power Mode keep the snow still. Snow stays behind your content."
        )
        .font(.footnote)
      }
    }
  }
}
