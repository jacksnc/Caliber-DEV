#if canImport(SwiftUI)
import SwiftUI

extension DynamicTypeStyle {
    var textStyle: Font.TextStyle {
        switch self {
        case .largeTitle: return .largeTitle
        case .title: return .title
        case .title2: return .title2
        case .title3: return .title3
        case .headline: return .headline
        case .body: return .body
        case .callout: return .callout
        case .subheadline: return .subheadline
        case .footnote: return .footnote
        case .caption: return .caption
        case .caption2: return .caption2
        }
    }
}

extension TypeDesign {
    var fontDesign: Font.Design {
        switch self {
        case .default: return .default
        case .rounded: return .rounded
        }
    }
}

extension TypeWeight {
    var fontWeight: Font.Weight {
        switch self {
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        }
    }
}

extension HeliosTypeRole {
    /// A font built only from a Dynamic Type text style, so it scales with the user's setting (never a fixed size).
    public var font: Font {
        let spec = self.spec
        let base = Font.system(spec.style.textStyle, design: spec.design.fontDesign, weight: spec.weight.fontWeight)
        return spec.monospacedDigit ? base.monospacedDigit() : base
    }
}

extension View {
    public func heliosFont(_ role: HeliosTypeRole) -> some View {
        font(role.font)
    }
}
#endif
