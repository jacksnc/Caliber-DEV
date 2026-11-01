import CaliberCore
import HeliosDesign
import SwiftUI

/// Sparse procedural six-arm flakes behind content, never an input or accessibility element.
/// Only a visible, active December screen runs its 15fps canvas. Accessibility/power modes
/// draw a static, smaller field instead of scheduling animation updates.
struct SeasonalSnowfall: View {
  @Environment(\.seasonalAppearance) private var season
  @Environment(\.scenePhase) private var phase
  @Environment(\.colorScheme) private var scheme
  @Environment(\.colorSchemeContrast) private var contrast
  @Environment(\.seasonalTestingReduceMotion) private var testingReduceMotion
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  @AppStorage("appearance.christmas.snowMotion.v1") private var motionEnabled = true
  @State private var visible = false
  @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled

  private var animates: Bool {
    SeasonalAppearancePolicy.animatesSnow(
      appearance: season, isVisible: visible, isActive: phase == .active,
      reduceMotion: reduceMotion || testingReduceMotion, reduceTransparency: reduceTransparency,
      increasedContrast: contrast == .increased, lowPower: lowPower, motionEnabled: motionEnabled)
  }

  var body: some View {
    Group {
      if animates {
        TimelineView(.animation(minimumInterval: 1.0 / 15)) { frame in
          snow(elapsed: frame.date.timeIntervalSinceReferenceDate, count: 22)
        }
      } else {
        snow(elapsed: 0, count: 8)
      }
    }
    .ignoresSafeArea()
    .allowsHitTesting(false)
    .accessibilityHidden(true)
    .onAppear { visible = true }
    .onDisappear { visible = false }
    .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
      lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    }
  }

  private func snow(elapsed: TimeInterval, count: Int) -> some View {
    Canvas(rendersAsynchronously: true) { context, size in
      guard size.width > 0, size.height > 0 else { return }
      let color =
        scheme == .dark
        ? Color.white.opacity(0.23) : Color(red: 0.26, green: 0.38, blue: 0.48).opacity(0.22)
      for index in 0..<count {
        let seed = Double((index * 47 + 13) % 101) / 101
        let duration = 18 + Double(index % 13)
        let travel = size.height + 24
        let progress = (elapsed / duration + Double((index * 37 + 7) % 101) / 101)
          .truncatingRemainder(dividingBy: 1)
        let drift = sin(elapsed / 9 + Double(index)) * 7
        let x = seed * size.width + drift
        let y = progress * travel - 12
        let radius = 3 + Double(index % 4)
        var local = context
        local.translateBy(x: x, y: y)
        local.rotate(by: .radians(Double(index) * 0.7))
        local.stroke(
          flake(radius: radius), with: .color(color),
          style: StrokeStyle(lineWidth: 0.8, lineCap: .round))
      }
    }
  }

  private func flake(radius: Double) -> Path {
    Path { path in
      for arm in 0..<6 {
        let angle = Double(arm) * .pi / 3
        func point(_ distance: Double, _ offset: Double = 0) -> CGPoint {
          CGPoint(x: cos(angle + offset) * distance, y: sin(angle + offset) * distance)
        }
        path.move(to: .zero)
        path.addLine(to: point(radius))
        path.move(to: point(radius * 0.56))
        path.addLine(to: point(radius * 0.83, 0.24))
        path.move(to: point(radius * 0.56))
        path.addLine(to: point(radius * 0.83, -0.24))
      }
    }
  }
}
