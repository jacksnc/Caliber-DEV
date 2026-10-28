import CaliberCore
import HeliosDesign
import SwiftUI

/// The theme choice drawn as small previews of each palette's canvas, glass and macro colours.
/// It edits the same `AppTheme` setting as the Settings picker, so nothing new is stored.
/// Each preview is one button; selection is an accent edge, a check mark and the selected trait,
/// never colour alone. Previews follow Increase Contrast and Reduce Transparency, and nothing
/// animates.
///
/// Intended insertion (Codex), in the Appearance section of `FoundationSettingsView`:
/// `AppearancePreviewPicker(selection: $runtime.settings.theme)`
struct AppearancePreviewPicker: View {
  @Binding var selection: AppTheme
  @Environment(\.dynamicTypeSize) private var typeSize

  var body: some View {
    // One column at accessibility sizes, so names wrap instead of shrinking.
    let columns = Array(
      repeating: GridItem(.flexible(), spacing: HeliosTokens.space(3), alignment: .top),
      count: typeSize.isAccessibilitySize ? 1 : 2)
    LazyVGrid(columns: columns, spacing: HeliosTokens.space(3)) {
      ForEach(AppTheme.allCases, id: \.self) { option in
        AppearancePreviewOption(option: option, isSelected: option == selection) {
          selection = option
        }
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Theme")
    .accessibilityIdentifier("appearancePreview")
  }
}

private struct AppearancePreviewOption: View {
  let option: AppTheme
  let isSelected: Bool
  let select: () -> Void
  @Environment(\.heliosTheme) private var theme
  @Environment(\.colorSchemeContrast) private var contrast
  @ScaledMetric(relativeTo: .body) private var swatchHeight = 88.0

  var body: some View {
    let palette = theme.palette
    let shape = RoundedRectangle(cornerRadius: HeliosTokens.radius.tile, style: .continuous)
    Button(action: select) {
      VStack(alignment: .leading, spacing: HeliosTokens.space(2)) {
        swatch
          .frame(maxWidth: .infinity)
          .frame(height: swatchHeight)
          .clipShape(
            RoundedRectangle(cornerRadius: HeliosTokens.radius.chip, style: .continuous)
          )
          .accessibilityHidden(true)
        HStack(alignment: .firstTextBaseline, spacing: HeliosTokens.space(2)) {
          Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .foregroundStyle(
              isSelected ? palette.accent.base.color : palette.text.secondary.color
            )
            .accessibilityHidden(true)
          VStack(alignment: .leading, spacing: 0) {
            Text(option.previewTitle)
              .heliosFont(.bodyStrong)
              .foregroundStyle(palette.text.primary.color)
              .fixedSize(horizontal: false, vertical: true)
            Text(option.previewDetail)
              .heliosFont(.caption)
              .foregroundStyle(palette.text.secondary.color)
              .fixedSize(horizontal: false, vertical: true)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
      .padding(HeliosTokens.space(2))
      .frame(maxWidth: .infinity, minHeight: HeliosTokens.minimumTapTarget, alignment: .leading)
      .background {
        shape.fill(isSelected ? palette.accent.subtle.color : Color.clear)
      }
      .overlay {
        shape.strokeBorder(edgeColor, lineWidth: isSelected || palette.isHighContrast ? 2 : 1)
      }
      .contentShape(shape)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(Text(option.previewTitle))
    .accessibilityHint(Text(option.previewDetail))
    .accessibilityAddTraits(isSelected ? .isSelected : [])
    .accessibilityIdentifier("appearanceTheme-" + option.rawValue)
  }

  private var edgeColor: Color {
    let palette = theme.palette
    if isSelected { return palette.accent.base.color }
    return palette.isHighContrast ? palette.border.strong.color : palette.border.hairline.color
  }

  @ViewBuilder private var swatch: some View {
    let increased = contrast == .increased
    let light = HeliosPalette.palette(dark: false, increasedContrast: increased)
    let dark = HeliosPalette.palette(dark: true, increasedContrast: increased)
    switch option {
    case .system:
      // Half Frost, half Graphite: the device decides which one is used.
      HStack(spacing: 0) {
        AppearanceSwatch(palette: light)
        AppearanceSwatch(palette: dark)
      }
    case .light:
      AppearanceSwatch(palette: light)
    case .dark:
      AppearanceSwatch(palette: dark)
    case .oled:
      AppearanceSwatch(palette: dark, blackCanvas: true)
    }
  }
}

/// A miniature screen in a given palette: canvas, one glass card, two text lines, the three
/// macro colours and the accent. Decorative only; the option's text names the theme.
private struct AppearanceSwatch: View {
  let palette: HeliosPalette
  var blackCanvas = false
  @Environment(\.heliosTheme) private var theme

  var body: some View {
    ZStack {
      if blackCanvas {
        Color.black
      } else {
        LinearGradient(
          colors: [palette.canvasTop.color, palette.canvasBottom.color],
          startPoint: .top, endPoint: .bottom)
      }
      VStack(alignment: .leading, spacing: 6) {
        Capsule().fill(palette.text.primary.color).frame(width: 36, height: 6)
        Capsule().fill(palette.text.secondary.color).frame(width: 24, height: 4)
        HStack(spacing: 4) {
          Circle().fill(palette.data.protein.color).frame(width: 8, height: 8)
          Circle().fill(palette.data.carbs.color).frame(width: 8, height: 8)
          Circle().fill(palette.data.fat.color).frame(width: 8, height: 8)
        }
        Capsule().fill(palette.accent.base.color).frame(width: 30, height: 8)
      }
      .padding(8)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background { GlassBackground(level: .base, cornerRadius: 10) }
      .padding(10)
    }
    // The card inside draws with the previewed palette, keeping the viewer's Reduce Transparency.
    .environment(
      \.heliosTheme, HeliosTheme(palette: palette, reduceTransparency: theme.reduceTransparency))
  }
}

extension AppTheme {
  /// The same names as the Settings picker.
  fileprivate var previewTitle: LocalizedStringKey {
    switch self {
    case .system: "System"
    case .light: "Frost (Light)"
    case .dark: "Graphite (Dark)"
    case .oled: "OLED Black"
    }
  }

  fileprivate var previewDetail: LocalizedStringKey {
    switch self {
    case .system: "Follows your device"
    case .light: "White and light blue"
    case .dark: "Grey and black glass"
    case .oled: "True black background"
    }
  }
}

private struct AppearancePreviewPickerPreview: View {
  @State private var theme = AppTheme.dark

  var body: some View {
    AppearancePreviewPicker(selection: $theme)
      .padding()
      .heliosThemed()
  }
}

#Preview {
  AppearancePreviewPickerPreview()
}
