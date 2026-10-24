import Foundation

/// Soft ambient light behind the glass. Positions and radius are fractions of the screen.
public struct HeliosGlow: Hashable, Sendable {
    public var color: RGBA
    public var opacity: Double
    public var x: Double
    public var y: Double
    public var radius: Double

    public init(color: RGBA, opacity: Double, x: Double, y: Double, radius: Double) {
        self.color = color
        self.opacity = opacity
        self.x = x
        self.y = y
        self.radius = radius
    }
}

public enum GlassLevel: String, CaseIterable, Sendable {
    /// Cards that sit on the canvas.
    case base
    /// Tiles and controls on top of a card.
    case raised
    /// Sheets, menus and anything that floats.
    case overlay
}

/// One value per glass level. For glass these are translucent tints; for the Reduce Transparency fallback they are opaque.
public struct GlassLevels: Hashable, Sendable {
    public var base: RGBA
    public var raised: RGBA
    public var overlay: RGBA

    public init(base: RGBA, raised: RGBA, overlay: RGBA) {
        self.base = base
        self.raised = raised
        self.overlay = overlay
    }

    public subscript(level: GlassLevel) -> RGBA {
        switch level {
        case .base: return base
        case .raised: return raised
        case .overlay: return overlay
        }
    }
}

public struct BorderTokens: Hashable, Sendable {
    /// Top-leading edge of the glass border gradient.
    public var highlight: RGBA
    /// Bottom-trailing edge of the border gradient.
    public var lowlight: RGBA
    public var hairline: RGBA
    /// The border used by the increased-contrast palettes to give every control a clear edge (needs 3:1).
    public var strong: RGBA

    public init(highlight: RGBA, lowlight: RGBA, hairline: RGBA, strong: RGBA) {
        self.highlight = highlight
        self.lowlight = lowlight
        self.hairline = hairline
        self.strong = strong
    }
}

public struct ShadowToken: Hashable, Sendable {
    public var color: RGBA
    public var radius: Double
    public var y: Double

    public init(color: RGBA, radius: Double, y: Double) {
        self.color = color
        self.radius = radius
        self.y = y
    }
}

public struct TextColors: Hashable, Sendable {
    public var primary: RGBA
    public var secondary: RGBA
    /// Captions, units and hints only: it clears 3:1 but not 4.5:1 in the standard palettes.
    public var tertiary: RGBA
    /// Text drawn on a solid accent fill.
    public var onAccent: RGBA

    public init(primary: RGBA, secondary: RGBA, tertiary: RGBA, onAccent: RGBA) {
        self.primary = primary
        self.secondary = secondary
        self.tertiary = tertiary
        self.onAccent = onAccent
    }
}

public struct AccentColors: Hashable, Sendable {
    public var base: RGBA
    public var pressed: RGBA
    /// Selected-row and highlighted-chip wash.
    public var subtle: RGBA
    public var focus: RGBA
    /// Light-blue fill for chips and selected states.
    public var tint: RGBA

    public init(base: RGBA, pressed: RGBA, subtle: RGBA, focus: RGBA, tint: RGBA) {
        self.base = base
        self.pressed = pressed
        self.subtle = subtle
        self.focus = focus
        self.tint = tint
    }
}

/// Colours by meaning. A series keeps its colour in every chart, tile and legend.
public struct DataColors: Hashable, Sendable {
    public var energy: RGBA
    public var protein: RGBA
    public var carbs: RGBA
    public var fat: RGBA
    public var training: RGBA
    public var peptide: RGBA
    public var weight: RGBA
    public var reference: RGBA

    public init(energy: RGBA, protein: RGBA, carbs: RGBA, fat: RGBA, training: RGBA, peptide: RGBA, weight: RGBA, reference: RGBA) {
        self.energy = energy
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.training = training
        self.peptide = peptide
        self.weight = weight
        self.reference = reference
    }

    public static let names = ["energy", "protein", "carbs", "fat", "training", "peptide", "weight", "reference"]
    /// The six chromatic series colours (weight and reference are neutrals).
    public static let hueNames = ["energy", "protein", "carbs", "fat", "training", "peptide"]

    public func color(named name: String) -> RGBA? {
        switch name {
        case "energy": return energy
        case "protein": return protein
        case "carbs": return carbs
        case "fat": return fat
        case "training": return training
        case "peptide": return peptide
        case "weight": return weight
        case "reference": return reference
        default: return nil
        }
    }
}

public struct StatusColors: Hashable, Sendable {
    public var success: RGBA
    public var warning: RGBA
    public var danger: RGBA

    public init(success: RGBA, warning: RGBA, danger: RGBA) {
        self.success = success
        self.warning = warning
        self.danger = danger
    }
}

public struct HeliosPalette: Hashable, Sendable {
    public var id: String
    public var label: String
    public var isDark: Bool
    public var isHighContrast: Bool
    public var canvasTop: RGBA
    public var canvasBottom: RGBA
    public var glows: [HeliosGlow]
    public var glass: GlassLevels
    public var opaque: GlassLevels
    public var border: BorderTokens
    public var shadow: ShadowToken
    public var text: TextColors
    public var accent: AccentColors
    public var data: DataColors
    public var status: StatusColors

    public init(
        id: String, label: String, isDark: Bool, isHighContrast: Bool,
        canvasTop: RGBA, canvasBottom: RGBA, glows: [HeliosGlow],
        glass: GlassLevels, opaque: GlassLevels, border: BorderTokens, shadow: ShadowToken,
        text: TextColors, accent: AccentColors, data: DataColors, status: StatusColors
    ) {
        self.id = id
        self.label = label
        self.isDark = isDark
        self.isHighContrast = isHighContrast
        self.canvasTop = canvasTop
        self.canvasBottom = canvasBottom
        self.glows = glows
        self.glass = glass
        self.opaque = opaque
        self.border = border
        self.shadow = shadow
        self.text = text
        self.accent = accent
        self.data = data
        self.status = status
    }

    public static let all: [HeliosPalette] = [.dark, .light, .darkHighContrast, .lightHighContrast]

    /// The palette for a colour scheme and the Increase Contrast accessibility setting.
    public static func palette(dark: Bool, increasedContrast: Bool) -> HeliosPalette {
        switch (dark, increasedContrast) {
        case (true, false): return .dark
        case (false, false): return .light
        case (true, true): return .darkHighContrast
        case (false, true): return .lightHighContrast
        }
    }
}

// MARK: Non-colour tokens

public struct HeliosRadius: Hashable, Sendable {
    public var chip: Double
    public var button: Double
    public var tile: Double
    public var card: Double
    public var sheet: Double

    public init(chip: Double, button: Double, tile: Double, card: Double, sheet: Double) {
        self.chip = chip
        self.button = button
        self.tile = tile
        self.card = card
        self.sheet = sheet
    }
}

public struct HeliosGlassSpec: Hashable, Sendable {
    public var blur: Double
    public var saturation: Double

    public init(blur: Double, saturation: Double) {
        self.blur = blur
        self.saturation = saturation
    }
}

public struct HeliosMotion: Hashable, Sendable {
    public var fast: Double
    public var base: Double
    public var slow: Double
    public var springResponse: Double
    public var springDamping: Double

    public init(fast: Double, base: Double, slow: Double, springResponse: Double, springDamping: Double) {
        self.fast = fast
        self.base = base
        self.slow = slow
        self.springResponse = springResponse
        self.springDamping = springDamping
    }
}

/// Dynamic Type text styles. Typography is expressed only through these, never as point sizes, so every piece of text
/// scales with the user's setting by construction.
public enum DynamicTypeStyle: String, CaseIterable, Sendable {
    case largeTitle, title, title2, title3, headline, body, callout, subheadline, footnote, caption, caption2
}

public enum TypeDesign: String, Sendable { case `default`, rounded }
public enum TypeWeight: String, Sendable { case regular, medium, semibold, bold }

public struct HeliosTypeSpec: Hashable, Sendable {
    public var style: DynamicTypeStyle
    public var design: TypeDesign
    public var weight: TypeWeight
    public var monospacedDigit: Bool

    public init(style: DynamicTypeStyle, design: TypeDesign, weight: TypeWeight, monospacedDigit: Bool) {
        self.style = style
        self.design = design
        self.weight = weight
        self.monospacedDigit = monospacedDigit
    }
}

/// Colours that can share one chart, so any two may sit side by side. Distances are OKLab x 100.
public struct HeliosChartGroup: Hashable, Sendable {
    public var name: String
    public var members: [String]
    /// Smallest distance between any two members under normal colour vision.
    public var minNormal: Double
    /// Smallest distance between any two members under protanopia and deuteranopia.
    public var minCVD: Double

    public init(name: String, members: [String], minNormal: Double, minCVD: Double) {
        self.name = name
        self.members = members
        self.minNormal = minNormal
        self.minCVD = minCVD
    }
}
