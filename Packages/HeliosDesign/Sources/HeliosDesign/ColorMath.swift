import Foundation

public enum ColorMath {
    // MARK: WCAG

    static func linear(_ channel: Double) -> Double {
        channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
    }

    static func gamma(_ channel: Double) -> Double {
        channel <= 0.0031308 ? 12.92 * channel : 1.055 * pow(channel, 1 / 2.4) - 0.055
    }

    /// WCAG 2.x relative luminance of an opaque colour (alpha is ignored; composite first).
    public static func relativeLuminance(_ color: RGBA) -> Double {
        0.2126 * linear(color.red) + 0.7152 * linear(color.green) + 0.0722 * linear(color.blue)
    }

    /// WCAG contrast ratio, 1...21. Both colours must already be opaque.
    public static func contrastRatio(_ a: RGBA, _ b: RGBA) -> Double {
        let la = relativeLuminance(a), lb = relativeLuminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    // MARK: CIE Lab

    public struct Lab: Equatable, Sendable {
        public var lightness: Double
        public var a: Double
        public var b: Double
    }

    public static func lab(_ color: RGBA) -> Lab {
        let r = linear(color.red), g = linear(color.green), b = linear(color.blue)
        let x = (0.4124564 * r + 0.3575761 * g + 0.1804375 * b) / 0.95047
        let y = 0.2126729 * r + 0.7151522 * g + 0.0721750 * b
        let z = (0.0193339 * r + 0.1191920 * g + 0.9503041 * b) / 1.08883
        func f(_ t: Double) -> Double { t > 216.0 / 24389.0 ? cbrt(t) : (24389.0 / 27.0 * t + 16) / 116 }
        let fx = f(x), fy = f(y), fz = f(z)
        return Lab(lightness: 116 * fy - 16, a: 500 * (fx - fy), b: 200 * (fy - fz))
    }

    /// CIE76 colour difference. Crude next to CIEDE2000 but monotonic, simple, and plenty for "are these separable".
    public static func deltaE76(_ a: RGBA, _ b: RGBA) -> Double {
        let p = lab(a), q = lab(b)
        let dl = p.lightness - q.lightness, da = p.a - q.a, db = p.b - q.b
        return (dl * dl + da * da + db * db).squareRoot()
    }

    // MARK: Colour-vision deficiency

    public enum ColorVisionDeficiency: String, CaseIterable, Sendable {
        case protanopia, deuteranopia, tritanopia

        /// Machado, Oliveira and Fernandes (2009), severity 1.0, applied in linear RGB.
        var matrix: [[Double]] {
            switch self {
            case .protanopia:
                return [[0.152286, 1.052583, -0.204868], [0.114503, 0.786281, 0.099216], [-0.003882, -0.048116, 1.051998]]
            case .deuteranopia:
                return [[0.367322, 0.860646, -0.227968], [0.280085, 0.672501, 0.047413], [-0.011820, 0.042940, 0.968881]]
            case .tritanopia:
                return [[1.255528, -0.076749, -0.178779], [-0.078411, 0.930809, 0.147602], [0.004733, 0.691367, 0.303900]]
            }
        }

        public func simulate(_ color: RGBA) -> RGBA {
            let input = [ColorMath.linear(color.red), ColorMath.linear(color.green), ColorMath.linear(color.blue)]
            func channel(_ row: Int) -> Double {
                let value = (0..<3).reduce(0.0) { $0 + matrix[row][$1] * input[$1] }
                return ColorMath.gamma(min(max(value, 0), 1))
            }
            return RGBA(red: channel(0), green: channel(1), blue: channel(2), alpha: color.alpha)
        }
    }

    /// Smallest pairwise CIE76 distance between `colors`, as seen under `deficiency` (nil = normal vision).
    public static func minimumSeparation(_ colors: [RGBA], under deficiency: ColorVisionDeficiency? = nil) -> Double {
        let seen = colors.map { deficiency?.simulate($0) ?? $0 }
        var smallest = Double.infinity
        for i in seen.indices {
            for j in seen.indices where j > i {
                smallest = min(smallest, deltaE76(seen[i], seen[j]))
            }
        }
        return smallest
    }
}
