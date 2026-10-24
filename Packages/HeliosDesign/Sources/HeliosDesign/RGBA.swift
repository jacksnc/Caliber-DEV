import Foundation

/// An sRGB colour with straight (non-premultiplied) alpha. Channels are gamma-encoded, 0...1.
public struct RGBA: Hashable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    /// `RGBA(0x8AD0FF)` or `RGBA(0xFFFFFF, alpha: 0.05)`.
    public init(_ rgb: UInt32, alpha: Double = 1) {
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255,
            alpha: alpha
        )
    }

    /// "#RRGGBB" (alpha is not part of the string).
    public var hex: String {
        func byte(_ value: Double) -> Int { Int((min(max(value, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", byte(red), byte(green), byte(blue))
    }

    public func withAlpha(_ alpha: Double) -> RGBA {
        RGBA(red: red, green: green, blue: blue, alpha: alpha)
    }

    /// Source-over compositing in gamma-encoded sRGB, which is how UIKit, SwiftUI and CSS blend by default.
    public func composited(over background: RGBA) -> RGBA {
        let outAlpha = alpha + background.alpha * (1 - alpha)
        guard outAlpha > 0 else { return RGBA(red: 0, green: 0, blue: 0, alpha: 0) }
        func mix(_ foreground: Double, _ behind: Double) -> Double {
            (foreground * alpha + behind * background.alpha * (1 - alpha)) / outAlpha
        }
        return RGBA(red: mix(red, background.red), green: mix(green, background.green), blue: mix(blue, background.blue), alpha: outAlpha)
    }

    /// Linear interpolation between two colours (used for the canvas gradient).
    public func mixed(with other: RGBA, amount: Double) -> RGBA {
        let t = min(max(amount, 0), 1)
        return RGBA(
            red: red + (other.red - red) * t,
            green: green + (other.green - green) * t,
            blue: blue + (other.blue - blue) * t,
            alpha: alpha + (other.alpha - alpha) * t
        )
    }
}
