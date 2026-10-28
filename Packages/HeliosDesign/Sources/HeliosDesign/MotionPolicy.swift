import Foundation

/// How fast a Helios change runs. The durations are the `motion` tokens.
public enum HeliosMotionSpeed: Sendable, CaseIterable {
    case fast, base, slow

    public var duration: Double {
        switch self {
        case .fast: return HeliosTokens.motion.fast
        case .base: return HeliosTokens.motion.base
        case .slow: return HeliosTokens.motion.slow
        }
    }
}

/// The motion rules in one place, so the SwiftUI modifiers and the tests agree. The tokens allow a crossfade only under
/// Reduce Motion: nothing rises, scales, sweeps, bursts or waits on a stagger, and nothing ever loops.
public struct HeliosMotionPolicy: Equatable, Sendable {
    public var reduceMotion: Bool

    public init(reduceMotion: Bool) {
        self.reduceMotion = reduceMotion
    }

    /// Delay between cards in a cascading entrance: a quarter of the fast token.
    public static let staggerStep: Double = HeliosTokens.motion.fast / 4
    /// Cards past this position enter with the last one, so a long screen never waits on its tail.
    public static let maxStaggerSteps = 4
    /// The build brief caps a chart draw-in at 400 ms.
    public static let drawInLimit: Double = 0.4
    /// How long a toast stays on screen.
    public static let toastSeconds: Double = 2.6
    /// With VoiceOver on, a toast stays long enough for its announcement and a swipe to reach it.
    public static let toastSecondsVoiceOver: Double = 6

    /// Points a card rises while it fades in.
    public var entranceOffset: Double { reduceMotion ? 0 : 14 }
    /// Scale a card grows from while it fades in.
    public var entranceScale: Double { reduceMotion ? 1 : 0.97 }
    /// Scale of a pressed tile.
    public var pressedScale: Double { reduceMotion ? 1 : 0.97 }
    /// Opacity of a pressed tile; under Reduce Motion this dim is the whole press cue.
    public var pressedOpacity: Double { reduceMotion ? 0.75 : 0.92 }
    /// The light sweep across glass, celebration sparks and scroll scaling are movement, so they go.
    public var allowsFlourish: Bool { !reduceMotion }

    public func entranceDelay(order: Int) -> Double {
        guard !reduceMotion else { return 0 }
        return Double(min(max(order, 0), Self.maxStaggerSteps)) * Self.staggerStep
    }

    /// A draw-in reveals the chart left to right; under Reduce Motion it fades in on the fast token instead.
    public var drawInDuration: Double {
        reduceMotion ? HeliosTokens.motion.fast : min(HeliosTokens.motion.slow, Self.drawInLimit)
    }

    public static func toastDuration(voiceOver: Bool) -> Double {
        voiceOver ? toastSecondsVoiceOver : toastSeconds
    }
}
