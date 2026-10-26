import HeliosDesign
import SwiftUI

/// The primary destinations from the brief (§1.2): Today · Train · Fuel · Stack · Progress.
/// Stack is listed only after the person opts in to it.
enum CaliberTab: String, CaseIterable, Identifiable {
  case today, train, fuel, stack, progress

  var id: String { rawValue }

  var title: LocalizedStringKey {
    switch self {
    case .today: "Today"
    case .train: "Train"
    case .fuel: "Fuel"
    case .stack: "Stack"
    case .progress: "Progress"
    }
  }

  var symbol: String {
    switch self {
    case .today: "sun.max"
    case .train: "dumbbell"
    case .fuel: "fork.knife"
    case .stack: "cross.vial"
    case .progress: "chart.line.uptrend.xyaxis"
    }
  }
}

/// The floating glass tab bar with a detached Quick Log button, drawn to the look book
/// (`.tabbar` and `.fab` in design/lookbook/look.css).
struct CaliberTabBar: View {
  let tabs: [CaliberTab]
  @Binding var selection: CaliberTab
  let onQuickLog: () -> Void
  @Environment(\.heliosTheme) private var theme

  static let height: Double = 68

  var body: some View {
    HStack(alignment: .bottom, spacing: HeliosTokens.space(2)) {
      HStack(spacing: 2) {
        ForEach(tabs) { tab in
          CaliberTabButton(tab: tab, isSelected: selection == tab) { selection = tab }
        }
      }
      .padding(6)
      .frame(minHeight: Self.height)
      .background { GlassBackground(level: .overlay, cornerRadius: Self.height / 2) }

      Button(action: onQuickLog) {
        Image(systemName: "plus")
          .resizable()
          .scaledToFit()
          .fontWeight(.semibold)
          .frame(width: 24, height: 24)
          .frame(width: Self.height, height: Self.height)
          .foregroundStyle(theme.palette.text.onAccent.color)
          .background(Circle().fill(theme.palette.accent.base.color))
          .shadow(color: .black.opacity(0.3), radius: 12, y: 8)
          .contentShape(Circle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Quick Log")
      .accessibilityIdentifier("quickLog")
    }
    .padding(.horizontal, HeliosTokens.space(4))
    .padding(.bottom, HeliosTokens.space(2))
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("caliberTabBar")
  }
}

private struct CaliberTabButton: View {
  let tab: CaliberTab
  let isSelected: Bool
  let action: () -> Void
  @Environment(\.heliosTheme) private var theme
  @Environment(\.dynamicTypeSize) private var typeSize

  var body: some View {
    let palette = theme.palette
    Button(action: action) {
      VStack(spacing: 3) {
        Image(systemName: tab.symbol)
          .resizable()
          .scaledToFit()
          .fontWeight(isSelected ? .semibold : .regular)
          .frame(width: 22, height: 22)
        // Five labels cannot grow inside one bar. Above the xLarge text size the bar
        // shows icons only and long-press shows the large content viewer, as the system
        // bar does. The visible label is decoration: the button carries the name.
        if typeSize <= .xLarge {
          Text(tab.title).font(.caption2.weight(.medium)).accessibilityHidden(true)
        }
      }
      .frame(maxWidth: .infinity, minHeight: 56)
      .foregroundStyle(isSelected ? palette.accent.base.color : palette.text.secondary.color)
      .background {
        if isSelected { Capsule().fill(palette.accent.subtle.color) }
      }
      .contentShape(Capsule())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(Text(tab.title))
    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    .accessibilityIdentifier("tab-" + tab.rawValue)
    .accessibilityShowsLargeContentViewer {
      Label(tab.title, systemImage: tab.symbol)
    }
  }
}

/// Every primary screen keeps its content clear of the floating bar while still scrolling
/// beneath it.
extension View {
  func clearsCaliberTabBar() -> some View {
    safeAreaInset(edge: .bottom, spacing: 0) {
      Color.clear.frame(height: CaliberTabBar.height + HeliosTokens.space(4))
        .accessibilityHidden(true)
    }
  }
}

private struct SelectCaliberTabKey: EnvironmentKey {
  static let defaultValue: @MainActor (CaliberTab) -> Void = { _ in }
}

extension EnvironmentValues {
  /// Lets a card on one tab send the person to another, e.g. Today's "Start workout".
  var selectCaliberTab: @MainActor (CaliberTab) -> Void {
    get { self[SelectCaliberTabKey.self] }
    set { self[SelectCaliberTabKey.self] = newValue }
  }
}
