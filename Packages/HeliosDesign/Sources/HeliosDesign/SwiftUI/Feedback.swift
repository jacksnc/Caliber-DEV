#if canImport(SwiftUI)
import SwiftUI

// MARK: Toast

/// A short confirmation that floats in, such as "Dose logged". The caller passes text that is already localized and
/// an optional haptic that plays as it appears.
///
/// Caller contract: create a toast only after the save it confirms has succeeded (the write returned without error),
/// never on tap, optimistically, or after a failure. A failed save gets an inline error instead. The text states
/// what was saved; it never praises or judges a number (no "great deficit!").
public struct HeliosToast: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var symbol: String
    public var message: String
    public var haptic: HeliosHaptic?

    public init(symbol: String = "checkmark.circle.fill", message: String, haptic: HeliosHaptic? = nil) {
        self.id = UUID()
        self.symbol = symbol
        self.message = message
        self.haptic = haptic
    }
}

extension View {
    /// Shows `toast` at the top of this view, announces it to VoiceOver, and clears the binding after a few seconds
    /// (longer with VoiceOver on), on tap, or on the VoiceOver escape gesture. Setting a new toast replaces the current
    /// one. It drops in from the top, or fades under Reduce Motion. It sits on the opaque overlay tone with depth on
    /// top (audited as "toast" in `DeepGlassAudit`), because content scrolling underneath can't be predicted.
    public func heliosToast(_ toast: Binding<HeliosToast?>) -> some View {
        modifier(HeliosToastPresenter(toast: toast))
    }
}

private struct HeliosToastPresenter: ViewModifier {
    @Binding var toast: HeliosToast?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                ZStack {
                    if let toast {
                        HeliosToastView(toast: toast) { dismiss(toast.id) }
                            .padding(.horizontal, HeliosTokens.space(4))
                            .padding(.top, HeliosTokens.space(2))
                            .id(toast.id)
                            .transition(.heliosDrop(reduceMotion: reduceMotion))
                    }
                }
                .animation(reduceMotion ? .heliosCrossfade : .heliosSpring, value: toast?.id)
            }
            .sensoryFeedback(trigger: toast?.id) { _, newID in
                newID == nil ? nil : toast?.haptic?.feedback
            }
            .task(id: toast?.id) {
                guard let current = toast else { return }
                AccessibilityNotification.Announcement(current.message).post()
                try? await Task.sleep(for: .seconds(HeliosMotionPolicy.toastDuration(voiceOver: voiceOver)))
                guard !Task.isCancelled else { return }
                dismiss(current.id)
            }
    }

    private func dismiss(_ id: UUID) {
        if toast?.id == id { toast = nil }
    }
}

private struct HeliosToastView: View {
    let toast: HeliosToast
    let dismiss: () -> Void
    @Environment(\.heliosTheme) private var theme

    var body: some View {
        let palette = theme.palette
        Button(action: dismiss) {
            HStack(spacing: HeliosTokens.space(2)) {
                Image(systemName: toast.symbol)
                    .foregroundStyle(palette.accent.base.color)
                    .accessibilityHidden(true)
                Text(toast.message)
                    .heliosFont(.bodyStrong)
                    .foregroundStyle(palette.text.primary.color)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, HeliosTokens.space(4))
            .padding(.vertical, HeliosTokens.space(3))
            .frame(minHeight: HeliosTokens.minimumTapTarget)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: HeliosTokens.radius.sheet, style: .continuous)
                        .fill(palette.opaque.overlay.color)
                    HeliosDeepGlass(level: .overlay, cornerRadius: HeliosTokens.radius.sheet)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: HeliosTokens.radius.sheet, style: .continuous))
        }
        .buttonStyle(.heliosPressable)
        .accessibilityLabel(Text(toast.message))
        .accessibilityHint(Text("Dismisses this message"))
        .accessibilityAction(.escape, dismiss)
        .accessibilityIdentifier("heliosToast")
    }
}

// MARK: Celebration

private let heliosSparkCount = 12

/// A one-shot burst around whatever it is layered on (a badge, a ring), for a `HeliosAchievement`. Sparks fly out and
/// fade once per change of `trigger`; nothing plays at rest. Under Reduce Motion a ring glows and fades in place
/// instead. Decorative: hidden from VoiceOver, so announce the achievement in text (a toast does this).
///
/// Caller contract: change `trigger` only after the achievement has been saved, and not again when the screen
/// reappears or the record is recomputed on edit.
public struct HeliosCelebration<Trigger: Equatable>: View {
    private let achievement: HeliosAchievement
    private let trigger: Trigger
    private let colors: [Color]?
    @Environment(\.heliosTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// `colors` defaults to the training data colour and the accent.
    public init(_ achievement: HeliosAchievement, trigger: Trigger, colors: [Color]? = nil) {
        self.achievement = achievement
        self.trigger = trigger
        self.colors = colors
    }

    public var body: some View {
        let data = theme.palette.data
        let sparkColors = colors ?? [data.training.color, theme.palette.accent.base.color]
        let accent = theme.palette.accent.base.color
        GeometryReader { proxy in
            let width = Double(proxy.size.width)
            let height = Double(proxy.size.height)
            let radius = min(width, height) / 2
            if HeliosMotionPolicy(reduceMotion: reduceMotion).allowsFlourish {
                Color.clear
                    .keyframeAnimator(initialValue: 0.0, trigger: trigger) { view, progress in
                        view.overlay {
                            ZStack {
                                ForEach(0..<heliosSparkCount, id: \.self) { index in
                                    let angle = Double(index) / Double(heliosSparkCount) * 2 * Double.pi
                                    let distance = radius * (0.45 + 0.75 * progress)
                                    Capsule()
                                        .fill(sparkColors.isEmpty ? accent : sparkColors[index % sparkColors.count])
                                        .frame(width: 4, height: 11)
                                        .rotationEffect(.radians(angle + Double.pi / 2))
                                        .scaleEffect(1 - 0.5 * progress)
                                        .offset(x: cos(angle) * distance, y: sin(angle) * distance)
                                        .opacity(progress <= 0 || progress >= 1 ? 0 : 1 - progress)
                                }
                            }
                            .frame(width: width, height: height)
                        }
                    } keyframes: { _ in
                        CubicKeyframe(1.0, duration: HeliosTokens.motion.slow * 1.6)
                    }
            } else {
                Color.clear
                    .keyframeAnimator(initialValue: 0.0, trigger: trigger) { view, glow in
                        view.overlay {
                            Circle()
                                .stroke(accent, lineWidth: 3)
                                .frame(width: radius * 2, height: radius * 2)
                                .opacity(glow)
                        }
                    } keyframes: { _ in
                        LinearKeyframe(0.7, duration: HeliosTokens.motion.fast)
                        LinearKeyframe(0.0, duration: HeliosTokens.motion.slow)
                    }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
#endif
