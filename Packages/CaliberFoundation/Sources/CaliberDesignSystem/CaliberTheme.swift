import Foundation
import HeliosDesign
import SwiftUI

public enum CaliberTheme {
  public enum Appearance: String, CaseIterable, Sendable { case dark, light, oled }
  public enum Domain: String, CaseIterable, Sendable { case train, fuel, stack, body }
  public struct Palette: Sendable {
    public let background: Color
    public let surface: Color
    public let text: Color
    public let secondaryText: Color
    public let border: Color
    public let accent: Color
    public let train: Color
    public let fuel: Color
    public let stack: Color
    public let body: Color
    public func color(for domain: Domain) -> Color {
      switch domain {
      case .train: train
      case .fuel: fuel
      case .stack: stack
      case .body: body
      }
    }
  }
  public static let minimumInteractiveSize: CGFloat = 48
  public static let cardRadius: CGFloat = 18
  public static let controlRadius: CGFloat = 12
  public static let cardPadding: CGFloat = 16
  public static func palette(scheme: ColorScheme, increasedContrast: Bool = false) -> Palette {
    palette(appearance: scheme == .dark ? .dark : .light, increasedContrast: increasedContrast)
  }
  /// Compatibility adapter: existing charts use the same tokens as the app.
  public static func palette(appearance: Appearance, increasedContrast: Bool = false) -> Palette {
    let colors = HeliosPalette.palette(
      dark: appearance != .light, increasedContrast: increasedContrast)
    return Palette(
      background: appearance == .oled ? .black : colors.canvasTop.color,
      surface: colors.opaque.base.color, text: colors.text.primary.color,
      secondaryText: colors.text.secondary.color, border: colors.border.hairline.color,
      accent: colors.accent.base.color, train: colors.data.training.color,
      fuel: colors.data.energy.color, stack: colors.data.peptide.color,
      body: colors.data.weight.color)
  }
}

/// A shared string catalog allows translations without changing the views.
public enum CaliberCopy {
  public static func text(_ key: String.LocalizationValue, locale: Locale = .current) -> String {
    String(localized: key, bundle: .module, locale: locale)
  }
}
extension Color {
  fileprivate init(hex: String) {
    let value = UInt64(hex.dropFirst(), radix: 16) ?? 0
    self.init(
      .sRGB, red: Double((value >> 16) & 0xff) / 255,
      green: Double((value >> 8) & 0xff) / 255,
      blue: Double(value & 0xff) / 255, opacity: 1)
  }
}
public struct CaliberEmptyState: View {
  private let title: String
  private let message: String
  private let symbol: String
  @Environment(\.colorScheme) private var scheme
  @Environment(\.colorSchemeContrast) private var contrast
  public init(title: String, message: String, symbol: String = "chart.xyaxis.line") {
    self.title = title
    self.message = message
    self.symbol = symbol
  }
  public var body: some View {
    let palette = CaliberTheme.palette(scheme: scheme, increasedContrast: contrast == .increased)
    VStack(spacing: 12) {
      Image(systemName: symbol).font(.title).accessibilityHidden(true)
      Text(title).font(.headline).foregroundStyle(palette.text)
        .fixedSize(horizontal: false, vertical: true)
      Text(message).font(.body).foregroundStyle(palette.secondaryText).multilineTextAlignment(
        .center
      )
      .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity).padding(24).accessibilityElement(children: .combine)
  }
}
