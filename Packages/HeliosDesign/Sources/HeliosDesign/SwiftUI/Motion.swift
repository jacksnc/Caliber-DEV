#if canImport(SwiftUI)
import SwiftUI

// MARK: Curves

extension Animation {
    /// An ease on one of the duration tokens.
    public static func helios(_ speed: HeliosMotionSpeed) -> Animation {
        .easeInOut(duration: speed.duration)
    }

    /// The house spring from the tokens: quick, settles without a visible wobble.
    public static var heliosSpring: Animation {
        .spring(response: HeliosTokens.motion.springResponse, dampingFraction: HeliosTokens.motion.springDamping)
    }

    /// A slightly livelier spring for a press release or a celebration.
    public static var heliosBounce: Animation {
        .spring(response: HeliosTokens.motion.springResponse * 0.8, dampingFraction: 0.7)
    }

    /// The only animation Reduce Motion allows: a short crossfade.
    public static var heliosCrossfade: Animation {
        .easeInOut(duration: HeliosTokens.motion.fast)
    }
}

/// `withAnimation` that follows Reduce Motion: the given animation normally, a short crossfade otherwise. Use it for
/// state that inserts or removes views with a `heliosRise`/`heliosDrop` transition, which become fades too.
public func withHeliosAnimation<Result>(
    _ animation: Animation = .heliosSpring,
    reduceMotion: Bool,
    _ body: () throws -> Result
) rethrows -> Result {
    try withAnimation(reduceMotion ? .heliosCrossfade : animation, body)
}

// MARK: Transitions

extension AnyTransition {
    /// Rises a little from below as it fades in; a plain fade under Reduce Motion.
    public static func heliosRise(reduceMotion: Bool) -> AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .opacity.combined(with: .offset(y: 16)).combined(with: .scale(scale: 0.97, anchor: .bottom)),
            removal: .opacity.combined(with: .scale(scale: 0.98))
        )
    }

    /// Drops in from the top edge, for toasts; a plain fade under Reduce Motion.
    public static func heliosDrop(reduceMotion: Bool) -> AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.94, anchor: .top))
    }
}

// MARK: Modifiers

extension View {
    /// Animates changes to `value` with the given animation, or not at all under Reduce Motion.
    public func heliosAnimation<V: Equatable>(_ animation: Animation = .heliosSpring, value: V) -> some View {
        modifier(HeliosAnimationModifier(animation: animation, value: value))
    }

    /// Fades the view in on first appearance while it rises and settles. Give each card on a screen its position as
    /// `order` for a short cascade (capped after a few cards). Under Reduce Motion it only fades. Use it in eager
    /// stacks; a lazy stack would replay it as rows scroll back in.
    public func heliosEntrance(order: Int = 0) -> some View {
        modifier(HeliosEntrance(order: order))
    }

    /// Rolls changing digits like a counter. Under Reduce Motion the old number crossfades to the new one.
    public func heliosNumericTransition(value: Double) -> some View {
        modifier(HeliosNumericTransition(value: value))
    }

    /// Reveals a chart left to right on first appearance, within the brief's 400 ms. Under Reduce Motion it fades in.
    /// Only the drawing is masked; the chart's accessibility summary is there from the start.
    public func heliosDrawIn() -> some View {
        modifier(HeliosDrawIn())
    }

    /// Cards ease back and dim slightly as they scroll under the screen edges. Reduce Motion keeps the dim only;
    /// Increase Contrast turns the dim off too.
    public func heliosScrollDepth() -> some View {
        modifier(HeliosScrollDepth())
    }
}

private struct HeliosAnimationModifier<V: Equatable>: ViewModifier {
    let animation: Animation
    let value: V
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : animation, value: value)
    }
}

private struct HeliosEntrance: ViewModifier {
    let order: Int
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let policy = HeliosMotionPolicy(reduceMotion: reduceMotion)
        content
            .opacity(shown ? 1 : 0)
            .scaleEffect(shown ? 1 : policy.entranceScale, anchor: .top)
            .offset(y: shown ? 0 : policy.entranceOffset)
            .onAppear {
                guard !shown else { return }
                let animation: Animation = reduceMotion
                    ? .heliosCrossfade
                    : Animation.heliosSpring.delay(policy.entranceDelay(order: order))
                withAnimation(animation) { shown = true }
            }
    }
}

private struct HeliosNumericTransition: ViewModifier {
    let value: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .contentTransition(reduceMotion ? .opacity : .numericText(value: value))
            .animation(reduceMotion ? .heliosCrossfade : .heliosSpring, value: value)
    }
}

private struct HeliosDrawIn: ViewModifier {
    @State private var revealed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let policy = HeliosMotionPolicy(reduceMotion: reduceMotion)
        let wipes = !reduceMotion
        content
            .mask(alignment: .leading) {
                GeometryReader { proxy in
                    Rectangle()
                        .frame(width: wipes && !revealed ? 0 : proxy.size.width, height: proxy.size.height)
                }
            }
            .opacity(revealed ? 1 : 0)
            .onAppear {
                guard !revealed else { return }
                withAnimation(.easeOut(duration: policy.drawInDuration)) { revealed = true }
            }
    }
}

private struct HeliosScrollDepth: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.heliosTheme) private var theme

    func body(content: Content) -> some View {
        let scales = !reduceMotion
        let dims = !theme.palette.isHighContrast
        content.scrollTransition(.interactive, axis: .vertical) { view, phase in
            view
                .scaleEffect(scales ? 1 - min(abs(phase.value), 1) * 0.05 : 1)
                .opacity(dims ? 1 - min(abs(phase.value), 1) * 0.3 : 1)
        }
    }
}

// MARK: Press feedback

/// A plain button style for tappable cards and tiles: the label shrinks a touch and springs back. Under Reduce Motion
/// it dims instead. The label keeps its own look; use `heliosPrimary`/`heliosSecondary` for real buttons.
public struct HeliosPressableStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        HeliosPressableBody(configuration: configuration)
    }
}

private struct HeliosPressableBody: View {
    let configuration: ButtonStyle.Configuration
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let policy = HeliosMotionPolicy(reduceMotion: reduceMotion)
        configuration.label
            .scaleEffect(configuration.isPressed ? policy.pressedScale : 1)
            .opacity(configuration.isPressed ? policy.pressedOpacity : 1)
            .animation(reduceMotion ? .heliosCrossfade : .heliosBounce, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == HeliosPressableStyle {
    public static var heliosPressable: HeliosPressableStyle { HeliosPressableStyle() }
}

// MARK: Haptics

/// The moments the build brief gives a haptic, mapped to system feedback. Haptics are not motion, so they play under
/// Reduce Motion too; the system's own haptics switch still silences them.
public enum HeliosHaptic: Sendable, CaseIterable {
    case doseLogged
    case mealLogged
    case setComplete
    case personalRecord
    case restEnded
    case selection
    case limitReached

    var feedback: SensoryFeedback {
        switch self {
        case .doseLogged, .mealLogged: return .success
        case .setComplete: return .impact(weight: .medium)
        case .personalRecord: return .impact(weight: .heavy)
        case .restEnded: return .impact(flexibility: .rigid)
        case .selection: return .selection
        case .limitReached: return .warning
        }
    }
}

extension View {
    /// Plays the haptic whenever `trigger` changes.
    public func heliosHaptic<T: Equatable>(_ haptic: HeliosHaptic, trigger: T) -> some View {
        sensoryFeedback(haptic.feedback, trigger: trigger)
    }

    /// Plays the haptic when `trigger` changes and `condition(old, new)` holds, for example only when a count goes
    /// up and not when an entry is undone.
    public func heliosHaptic<T: Equatable>(
        _ haptic: HeliosHaptic,
        trigger: T,
        condition: @escaping (T, T) -> Bool
    ) -> some View {
        sensoryFeedback(haptic.feedback, trigger: trigger, condition: condition)
    }
}
#endif
