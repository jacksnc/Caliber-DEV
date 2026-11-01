import CaliberCore
import HeliosDesign
import SwiftUI
import WidgetKit

/// Small energy and medium macro cards. The extension consumes only the reviewed snapshot.
public struct NutritionWidgetView: View {
  public let snapshot: NutritionWidgetSnapshot
  public let now: Date
  @Environment(\.widgetFamily) private var family
  @Environment(\.colorScheme) private var scheme
  @Environment(\.colorSchemeContrast) private var contrast
  @Environment(\.dynamicTypeSize) private var textSize
  @Environment(\.redactionReasons) private var redaction

  public init(snapshot: NutritionWidgetSnapshot, now: Date) {
    self.snapshot = snapshot
    self.now = now
  }

  private var palette: HeliosPalette {
    HeliosPalette.palette(dark: scheme == .dark, increasedContrast: contrast == .increased)
  }
  private var state: NutritionWidgetDisplayState {
    snapshot.displayState(at: max(now, Date.now), timeZone: .current)
  }
  private let fuelURL = URL(string: "caliber://fuel")!
  private let addURL = URL(string: "caliber://food/add")!

  public var body: some View {
    Group {
      if textSize >= .xLarge {
        // Widgets cannot scroll or grow. Offer the full app rather than clip large text.
        Group {
          if family == .systemSmall {
            Text("Fuel").font(.body.bold())
              .fixedSize(horizontal: false, vertical: true)
          } else {
            Link("Open Fuel", destination: fuelURL).font(.body.bold())
              .fixedSize(horizontal: false, vertical: true)
          }
        }
        .accessibilityLabel("Caliber. Open Fuel in the app for full nutrition details.")
      } else if redaction.contains(.privacy) {
        neutral(title: "Caliber", detail: "Open Fuel")
      } else if state == .current, let values = snapshot.nutrition {
        populated(values).privacySensitive()
      } else {
        neutral(title: neutralTitle, detail: neutralDetail)
      }
    }
    .foregroundStyle(palette.text.primary.color)
    .widgetURL(fuelURL)
    .containerBackground(for: .widget) { palette.opaque.base.color }
  }

  private var neutralTitle: String {
    switch state {
    case .private: "Sharing is off"
    case .stale: "Update needed"
    case .unavailable, .current: "Data unavailable"
    }
  }
  private var neutralDetail: String {
    state == .private ? "Choose what to show in Caliber Settings." : "Open Caliber to refresh."
  }

  private func neutral(title: String, detail: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("CALIBER").font(.caption.weight(.semibold))
        .foregroundStyle(palette.text.secondary.color)
      Spacer(minLength: 0)
      Text(title).font(.headline).fixedSize(horizontal: false, vertical: true)
      if family == .systemMedium {
        Text(detail).font(.caption).foregroundStyle(palette.text.secondary.color)
          .fixedSize(horizontal: false, vertical: true)
      }
      Spacer(minLength: 0)
      Group {
        if family == .systemSmall {
          Text("Open Caliber")
        } else {
          Link("Open Caliber", destination: fuelURL)
        }
      }
      .font(.caption.bold()).foregroundStyle(palette.accent.base.color)
      .frame(minHeight: 32, alignment: .leading)
    }
  }

  private func populated(_ values: NutritionWidgetValues) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack {
        Text("FUEL TODAY").font(.caption.weight(.semibold))
        Spacer(minLength: 0)
        if family == .systemMedium {
          Text(snapshot.generatedAt, style: .time).font(.caption2)
            .accessibilityLabel(Text("Updated \(snapshot.generatedAt, style: .time)"))
        }
      }
      .foregroundStyle(palette.text.secondary.color)
      Spacer(minLength: 0)
      HStack(alignment: .center, spacing: 12) {
        VStack(alignment: .leading, spacing: 0) {
          Text(number(values.calories)).font(.largeTitle.weight(.semibold))
            .monospacedDigit().fixedSize(horizontal: false, vertical: true)
          Text("kcal logged").font(.caption)
            .foregroundStyle(palette.text.secondary.color)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(number(values.calories)) calories logged today"))
        if family == .systemMedium {
          Spacer(minLength: 0)
          VStack(alignment: .leading, spacing: 3) {
            macro("Protein", value: values.proteinGrams, color: palette.data.protein.color)
            macro("Carbs", value: values.carbohydrateGrams, color: palette.data.carbs.color)
            macro("Fat", value: values.fatGrams, color: palette.data.fat.color)
          }
        }
      }
      Spacer(minLength: 0)
      if family == .systemMedium {
        HStack {
          action("Open Fuel", destination: fuelURL)
          action("Add food", destination: addURL)
        }
      } else {
        Text("Open Fuel").font(.caption.bold()).foregroundStyle(palette.accent.base.color)
      }
    }
  }

  private func macro(_ name: LocalizedStringKey, value: Double, color: Color) -> some View {
    HStack(spacing: 4) {
      Circle().fill(color).frame(width: 5, height: 5).accessibilityHidden(true)
      Text(name)
      Text("\(number(value)) g").monospacedDigit()
    }
    .font(.caption).accessibilityElement(children: .combine)
  }

  private func action(_ title: LocalizedStringKey, destination: URL) -> some View {
    Link(destination: destination) {
      Text(title).font(.caption.bold())
        .frame(maxWidth: .infinity, minHeight: 48)
        .foregroundStyle(palette.accent.base.color)
        .background(palette.opaque.raised.color, in: RoundedRectangle(cornerRadius: 10))
    }
  }

  private func number(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(0)))
  }
}
