import CaliberCore
import HeliosDesign
import SwiftUI
import WidgetKit

/// Lookbook V2 native WidgetKit view supporting .systemSmall and .systemMedium.
/// Uses recorded kcal without invented goal rings.
/// Neutral states display no nutrition numbers for private, stale, or unavailable snapshots.
public struct NutritionWidgetView: View {
  @Environment(\.widgetFamily) private var family
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.colorSchemeContrast) private var contrast
  @Environment(\.dynamicTypeSize) private var typeSize

  public let snapshot: NutritionWidgetSnapshot
  public let now: Date

  public init(snapshot: NutritionWidgetSnapshot, now: Date = .now) {
    self.snapshot = snapshot
    self.now = now
  }

  private var palette: HeliosPalette {
    HeliosPalette.palette(
      dark: colorScheme == .dark,
      increasedContrast: contrast == .increased
    )
  }

  private var displayState: NutritionWidgetDisplayState {
    snapshot.displayState(at: now, timeZone: .current)
  }

  public var body: some View {
    Group {
      switch family {
      case .systemMedium:
        mediumLayout
      default:
        smallLayout
      }
    }
    .containerBackground(for: .widget) {
      widgetBackground
    }
  }

  // MARK: - Background

  private var widgetBackground: some View {
    ZStack {
      palette.opaque.surface.color
      if palette.isHighContrast {
        RoundedRectangle(cornerRadius: HeliosTokens.radius.tile)
          .strokeBorder(palette.border.strong.color, lineWidth: 1.5)
      }
    }
  }

  // MARK: - Small Layout (.systemSmall)

  @ViewBuilder
  private var smallLayout: some View {
    switch displayState {
    case .current:
      if let nutrition = snapshot.nutrition {
        smallPopulatedContent(nutrition)
          .widgetURL(URL(string: "caliber://fuel"))
      } else {
        smallNeutralContent(
          title: "CALIBER",
          message: "Data Unavailable",
          actionText: "Open Caliber",
          systemImage: "exclamationmark.triangle"
        )
        .widgetURL(URL(string: "caliber://fuel"))
      }
    case .private:
      smallNeutralContent(
        title: "CALIBER",
        message: "Sharing is Off",
        actionText: "Open Caliber",
        systemImage: "lock.slash.fill"
      )
      .widgetURL(URL(string: "caliber://fuel"))
    case .stale:
      smallNeutralContent(
        title: "CALIBER",
        message: "Update Needed",
        actionText: "Open Caliber",
        systemImage: "clock.arrow.circlepath"
      )
      .widgetURL(URL(string: "caliber://fuel"))
    case .unavailable:
      smallNeutralContent(
        title: "CALIBER",
        message: "Data Unavailable",
        actionText: "Open Caliber",
        systemImage: "exclamationmark.triangle"
      )
      .widgetURL(URL(string: "caliber://fuel"))
    }
  }

  private func smallPopulatedContent(_ nutrition: NutritionWidgetValues) -> some View {
    let caloriesInt = Int(nutrition.calories)
    let isAllZero = caloriesInt == 0 && Int(nutrition.proteinGrams) == 0
      && Int(nutrition.carbohydrateGrams) == 0 && Int(nutrition.fatGrams) == 0

    return VStack(alignment: .leading, spacing: 0) {
      HStack(alignment: .firstTextBaseline) {
        Text("FUEL")
          .heliosFont(.metricLabel)
          .foregroundStyle(palette.text.secondary.color)
          .fixedSize(horizontal: false, vertical: true)
        Spacer()
        Text("Today")
          .heliosFont(.caption)
          .foregroundStyle(palette.text.tertiary.color)
          .fixedSize(horizontal: false, vertical: true)
      }

      Spacer(minLength: HeliosTokens.space(1))

      VStack(alignment: .leading, spacing: 2) {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
          Text("\(caloriesInt)")
            .heliosFont(.display)
            .monospacedDigit()
            .foregroundStyle(palette.text.primary.color)
            .fixedSize(horizontal: false, vertical: true)
          Text("cal")
            .heliosFont(.footnote)
            .foregroundStyle(palette.text.secondary.color)
            .fixedSize(horizontal: false, vertical: true)
        }
        if isAllZero {
          Text("0 calories logged")
            .heliosFont(.caption)
            .foregroundStyle(palette.text.secondary.color)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      .privacySensitive()

      Spacer(minLength: HeliosTokens.space(1))

      if !typeSize.isAccessibilitySize {
        HStack(spacing: HeliosTokens.space(2)) {
          macroPill(label: "P", grams: nutrition.proteinGrams, color: palette.data.protein.color)
          macroPill(label: "C", grams: nutrition.carbohydrateGrams, color: palette.data.carbs.color)
          macroPill(label: "F", grams: nutrition.fatGrams, color: palette.data.fat.color)
        }
        .privacySensitive()

        Spacer(minLength: HeliosTokens.space(1))
      }

      HStack(spacing: 4) {
        Text("Open Fuel")
          .heliosFont(.caption)
          .fontWeight(.medium)
          .foregroundStyle(palette.accent.base.color)
          .fixedSize(horizontal: false, vertical: true)
        Image(systemName: "chevron.right")
          .font(.caption2.weight(.bold))
          .foregroundStyle(palette.accent.base.color)
      }
    }
    .padding(HeliosTokens.space(2))
    .accessibilityElement(children: .combine)
    .accessibilityLabel(
      isAllZero
        ? "Fuel Today: 0 calories logged. Protein 0 grams, Carbs 0 grams, Fat 0 grams. Open Fuel."
        : "Fuel Today: \(caloriesInt) calories. Protein \(Int(nutrition.proteinGrams)) grams, Carbs \(Int(nutrition.carbohydrateGrams)) grams, Fat \(Int(nutrition.fatGrams)) grams. Open Fuel."
    )
  }

  private func smallNeutralContent(
    title: String,
    message: String,
    actionText: String,
    systemImage: String
  ) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      Text(title)
        .heliosFont(.metricLabel)
        .foregroundStyle(palette.text.secondary.color)
        .fixedSize(horizontal: false, vertical: true)

      Spacer(minLength: HeliosTokens.space(1))

      VStack(alignment: .leading, spacing: HeliosTokens.space(1)) {
        Image(systemName: systemImage)
          .font(.title3.weight(.semibold))
          .foregroundStyle(palette.text.secondary.color)
        Text(message)
          .heliosFont(.bodyStrong)
          .foregroundStyle(palette.text.primary.color)
          .fixedSize(horizontal: false, vertical: true)
      }

      Spacer(minLength: HeliosTokens.space(1))

      HStack(spacing: 4) {
        Text(actionText)
          .heliosFont(.caption)
          .fontWeight(.medium)
          .foregroundStyle(palette.accent.base.color)
          .fixedSize(horizontal: false, vertical: true)
        Image(systemName: "chevron.right")
          .font(.caption2.weight(.bold))
          .foregroundStyle(palette.accent.base.color)
      }
    }
    .padding(HeliosTokens.space(2))
    .accessibilityElement(children: .combine)
    .accessibilityLabel(
      title == "CALIBER" && message == "Sharing is Off"
        ? "Caliber: Sharing is off. Choose what to show in Settings. Open Caliber."
        : "\(title): \(message). \(actionText)."
    )
  }

  // MARK: - Medium Layout (.systemMedium)

  @ViewBuilder
  private var mediumLayout: some View {
    switch displayState {
    case .current:
      if let nutrition = snapshot.nutrition {
        mediumPopulatedContent(nutrition)
      } else {
        mediumNeutralContent(
          title: "CALIBER",
          message: "Data Unavailable",
          detail: "Open Caliber to review your nutrition log."
        )
      }
    case .private:
      mediumNeutralContent(
        title: "CALIBER",
        message: "Sharing is Off",
        detail: "Choose what to show in Settings."
      )
    case .stale:
      mediumNeutralContent(
        title: "CALIBER",
        message: "Update Needed",
        detail: "Open Caliber to sync today's nutrition summary."
      )
    case .unavailable:
      mediumNeutralContent(
        title: "CALIBER",
        message: "Data Unavailable",
        detail: "Open Caliber to review your nutrition log."
      )
    }
  }

  private func mediumPopulatedContent(_ nutrition: NutritionWidgetValues) -> some View {
    let caloriesInt = Int(nutrition.calories)
    let isAllZero = caloriesInt == 0 && Int(nutrition.proteinGrams) == 0
      && Int(nutrition.carbohydrateGrams) == 0 && Int(nutrition.fatGrams) == 0

    return HStack(spacing: HeliosTokens.space(4)) {
      // Left Column: Energy & Navigation Links
      VStack(alignment: .leading, spacing: 0) {
        HStack(alignment: .firstTextBaseline) {
          Text("CALIBER FUEL")
            .heliosFont(.metricLabel)
            .foregroundStyle(palette.text.secondary.color)
            .fixedSize(horizontal: false, vertical: true)
          Spacer()
          Text("Today")
            .heliosFont(.caption)
            .foregroundStyle(palette.text.tertiary.color)
            .fixedSize(horizontal: false, vertical: true)
        }

        Spacer(minLength: HeliosTokens.space(1))

        VStack(alignment: .leading, spacing: 2) {
          HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("\(caloriesInt)")
              .heliosFont(.display)
              .monospacedDigit()
              .foregroundStyle(palette.text.primary.color)
              .fixedSize(horizontal: false, vertical: true)
            Text("cal")
              .heliosFont(.bodyStrong)
              .foregroundStyle(palette.text.secondary.color)
              .fixedSize(horizontal: false, vertical: true)
          }
          if isAllZero {
            Text("0 calories logged")
              .heliosFont(.caption)
              .foregroundStyle(palette.text.secondary.color)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
        .privacySensitive()

        Spacer(minLength: HeliosTokens.space(2))

        HStack(spacing: HeliosTokens.space(2)) {
          Link(destination: URL(string: "caliber://fuel")!) {
            Text("Open Fuel")
              .heliosFont(.caption)
              .fontWeight(.semibold)
              .foregroundStyle(palette.text.primary.color)
              .fixedSize(horizontal: false, vertical: true)
              .padding(.horizontal, HeliosTokens.space(3))
              .frame(minHeight: 44)
              .background {
                RoundedRectangle(cornerRadius: HeliosTokens.radius.chip, style: .continuous)
                  .fill(palette.opaque.raised.color)
              }
          }

          Link(destination: URL(string: "caliber://food/add")!) {
            Text("Add food")
              .heliosFont(.caption)
              .fontWeight(.semibold)
              .foregroundStyle(palette.accent.base.color)
              .fixedSize(horizontal: false, vertical: true)
              .padding(.horizontal, HeliosTokens.space(3))
              .frame(minHeight: 44)
              .background {
                RoundedRectangle(cornerRadius: HeliosTokens.radius.chip, style: .continuous)
                  .fill(palette.accent.tint.color)
              }
          }
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      // Divider hairline
      Rectangle()
        .fill(palette.border.hairline.color)
        .frame(width: 1)
        .padding(.vertical, HeliosTokens.space(1))

      // Right Column: Recorded Macro Breakdown
      VStack(alignment: .leading, spacing: HeliosTokens.space(2)) {
        macroRow(
          title: "Protein",
          grams: nutrition.proteinGrams,
          color: palette.data.protein.color
        )
        macroRow(
          title: "Carbs",
          grams: nutrition.carbohydrateGrams,
          color: palette.data.carbs.color
        )
        macroRow(
          title: "Fat",
          grams: nutrition.fatGrams,
          color: palette.data.fat.color
        )

        Spacer(minLength: 2)

        Text("Recorded intake")
          .heliosFont(.caption)
          .foregroundStyle(palette.text.tertiary.color)
          .fixedSize(horizontal: false, vertical: true)
      }
      .frame(width: typeSize.isAccessibilitySize ? 110 : 130, alignment: .leading)
      .privacySensitive()
    }
    .padding(HeliosTokens.space(3))
    .accessibilityElement(children: .contain)
  }

  private func mediumNeutralContent(
    title: String,
    message: String,
    detail: String
  ) -> some View {
    HStack(spacing: HeliosTokens.space(4)) {
      VStack(alignment: .leading, spacing: HeliosTokens.space(1)) {
        Text(title)
          .heliosFont(.metricLabel)
          .foregroundStyle(palette.text.secondary.color)
          .fixedSize(horizontal: false, vertical: true)

        Spacer(minLength: 2)

        Text(message)
          .heliosFont(.section)
          .foregroundStyle(palette.text.primary.color)
          .fixedSize(horizontal: false, vertical: true)
        Text(detail)
          .heliosFont(.footnote)
          .foregroundStyle(palette.text.secondary.color)
          .fixedSize(horizontal: false, vertical: true)

        Spacer(minLength: HeliosTokens.space(1))

        HStack(spacing: HeliosTokens.space(2)) {
          Link(destination: URL(string: "caliber://fuel")!) {
            Text("Open Caliber")
              .heliosFont(.caption)
              .fontWeight(.semibold)
              .foregroundStyle(palette.text.primary.color)
              .fixedSize(horizontal: false, vertical: true)
              .padding(.horizontal, HeliosTokens.space(3))
              .frame(minHeight: 44)
              .background {
                RoundedRectangle(cornerRadius: HeliosTokens.radius.chip, style: .continuous)
                  .fill(palette.opaque.raised.color)
              }
          }

          if message != "Sharing is Off" {
            Link(destination: URL(string: "caliber://food/add")!) {
              Text("Add food")
                .heliosFont(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(palette.accent.base.color)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, HeliosTokens.space(3))
                .frame(minHeight: 44)
                .background {
                  RoundedRectangle(cornerRadius: HeliosTokens.radius.chip, style: .continuous)
                    .fill(palette.accent.tint.color)
                }
            }
          }
        }
      }
    }
    .padding(HeliosTokens.space(3))
    .accessibilityElement(children: .contain)
    .accessibilityLabel(
      message == "Sharing is Off"
        ? "Caliber: Sharing is off. Choose what to show in Settings. Open Caliber."
        : "\(title): \(message). \(detail). Open Caliber."
    )
  }

  // MARK: - Macro Helpers

  private func macroPill(label: String, grams: Double, color: Color) -> some View {
    HStack(spacing: 3) {
      Circle()
        .fill(color)
        .frame(width: 6, height: 6)
      Text("\(label) \(Int(grams))g")
        .heliosFont(.caption)
        .foregroundStyle(palette.text.secondary.color)
        .monospacedDigit()
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private func macroRow(title: String, grams: Double, color: Color) -> some View {
    HStack(spacing: HeliosTokens.space(2)) {
      Circle()
        .fill(color)
        .frame(width: 8, height: 8)
      Text(title)
        .heliosFont(.footnote)
        .foregroundStyle(palette.text.secondary.color)
        .fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: 2)
      Text("\(Int(grams)) g")
        .heliosFont(.bodyStrong)
        .monospacedDigit()
        .foregroundStyle(palette.text.primary.color)
        .fixedSize(horizontal: false, vertical: true)
    }
  }
}
