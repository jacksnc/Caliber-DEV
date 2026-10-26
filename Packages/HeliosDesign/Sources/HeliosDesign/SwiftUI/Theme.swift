#if canImport(SwiftUI)
import SwiftUI

extension RGBA {
    public var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

/// The palette in force plus the accessibility settings that change how glass is drawn.
public struct HeliosTheme: Equatable {
    public var palette: HeliosPalette
    /// Reduce Transparency: draw opaque surfaces instead of blurred glass.
    public var reduceTransparency: Bool

    public init(palette: HeliosPalette, reduceTransparency: Bool = false) {
        self.palette = palette
        self.reduceTransparency = reduceTransparency
    }
}

private struct HeliosThemeKey: EnvironmentKey {
    static let defaultValue = HeliosTheme(palette: .dark)
}

extension EnvironmentValues {
    public var heliosTheme: HeliosTheme {
        get { self[HeliosThemeKey.self] }
        set { self[HeliosThemeKey.self] = newValue }
    }
}

private struct HeliosThemeResolver: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        content.environment(
            \.heliosTheme,
            HeliosTheme(
                palette: .palette(dark: colorScheme == .dark, increasedContrast: contrast == .increased),
                reduceTransparency: reduceTransparency
            )
        )
    }
}

extension View {
    /// Resolves the Helios palette from the colour scheme, Increase Contrast and Reduce Transparency, and hands it to
    /// every descendant. Apply once at the root, below any `.preferredColorScheme`.
    public func heliosThemed() -> some View {
        modifier(HeliosThemeResolver())
    }
}

/// The appearance choice in Settings. `system` follows the device.
public enum ThemePreference: String, CaseIterable, Identifiable, Sendable {
    case system, dark, light

    public var id: String { rawValue }

    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .dark: return .dark
        case .light: return .light
        }
    }
}
#endif
