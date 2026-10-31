import HeliosDesign
import SwiftUI

private struct CaliberOLEDKey: EnvironmentKey {
  static let defaultValue = false
}

extension EnvironmentValues {
  var caliberOLED: Bool {
    get { self[CaliberOLEDKey.self] }
    set { self[CaliberOLEDKey.self] = newValue }
  }
}

/// Layout bounds only; text continues to use the full Dynamic Type range.
enum CaliberLayout {
  static let readableWidth: CGFloat = 720
  static let navigationWidth: CGFloat = 680
}

/// Shared canvas for every navigation destination, including sheets.
struct CaliberCanvas: View {
  @Environment(\.caliberOLED) private var oled

  var body: some View {
    Group {
      if oled {
        Color.black.ignoresSafeArea()
      } else {
        HeliosBackground()
      }
    }.accessibilityHidden(true)
  }
}

/// Lists retain native swipe actions and section grouping while using Helios surfaces.
struct CaliberRowBackground: View {
  @Environment(\.heliosTheme) private var theme

  var body: some View {
    Rectangle()
      .fill(
        theme.reduceTransparency ? theme.palette.opaque.base.color : theme.palette.glass.base.color
      )
      .overlay {
        if theme.palette.isHighContrast {
          Rectangle().strokeBorder(theme.palette.border.strong.color, lineWidth: 1.5)
        }
      }
      .accessibilityHidden(true)
  }
}

/// Separate icon and text layout avoids the system inline-symbol label clipping at AX sizes.
private struct CaliberLabelStyle: LabelStyle {
  func makeBody(configuration: Configuration) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 10) {
      configuration.icon.accessibilityHidden(true)
      configuration.title.fixedSize(horizontal: false, vertical: true)
    }
  }
}

private struct CaliberScreen: ViewModifier {
  @Environment(\.heliosTheme) private var theme

  func body(content: Content) -> some View {
    content
      .font(.body)
      .labelStyle(CaliberLabelStyle())
      .scrollContentBackground(.hidden)
      .frame(maxWidth: CaliberLayout.readableWidth)
      .frame(maxWidth: .infinity)
      .background { CaliberCanvas() }
      .foregroundStyle(
        theme.palette.text.primary.color, theme.palette.text.secondary.color,
        theme.palette.text.tertiary.color
      )
      .tint(theme.palette.accent.base.color)
  }
}

extension View {
  func caliberScreen() -> some View { modifier(CaliberScreen()) }
}

// Transient navigation chrome only. A rendered review footer owns its token
// until it disappears, including across navigation hosting-controller boundaries.
private struct CaliberReviewFooterPresenceKey: EnvironmentKey {
  static let defaultValue: ((UUID, Bool) -> Void)? = nil
}

extension EnvironmentValues {
  var caliberReviewFooterPresence: ((UUID, Bool) -> Void)? {
    get { self[CaliberReviewFooterPresenceKey.self] }
    set { self[CaliberReviewFooterPresenceKey.self] = newValue }
  }
}
