#if canImport(SwiftUI)
import SwiftUI

/// The canvas behind the glass: a vertical gradient with soft ambient light. Static on purpose (nothing animates, so
/// Reduce Motion needs no special case) and hidden from VoiceOver.
public struct HeliosBackground: View {
    @Environment(\.heliosTheme) private var theme

    public init() {}

    public var body: some View {
        let palette = theme.palette
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [palette.canvasTop.color, palette.canvasBottom.color],
                    startPoint: .top,
                    endPoint: .bottom
                )
                ForEach(Array(palette.glows.enumerated()), id: \.offset) { _, glow in
                    RadialGradient(
                        colors: [glow.color.color.opacity(glow.opacity), glow.color.color.opacity(0)],
                        center: UnitPoint(x: glow.x, y: glow.y),
                        startRadius: 0,
                        endRadius: max(proxy.size.width, proxy.size.height) * glow.radius
                    )
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
#endif
