import HeliosDesign
import SwiftUI

/// One page of a `CaliberInfoCardPager`: a stable identifier for automation and a
/// visible, spoken name.
protocol CaliberInfoCardPage: Hashable, Identifiable where ID == String {
  /// The page name shown on its tab and spoken in "Protein, page 2 of 4".
  var pageTitle: String { get }
}

/// An info card with swipeable pages. Only the value panel takes the drag, so vertical
/// scrolling and any editable rows elsewhere keep their gestures. Every page is also
/// reachable without a swipe: by name, by Previous/Next, and by VoiceOver's adjustable
/// action or named actions. Pages never advance on their own.
///
/// The pager owns no data and does no arithmetic: the caller passes the selection and draws
/// each page's panel from values it already has.
struct CaliberInfoCardPager<Page: CaliberInfoCardPage, Panel: View>: View {
  let pages: [Page]
  @Binding var selection: Page
  /// Prefix for accessibility identifiers, e.g. "todayFuel" → "todayFuel-page-protein".
  let identifier: String
  /// A short name for the whole card, read before the page ("Today's nutrition").
  let cardName: String
  /// An optional short value under each tab name ("134 g"), so every page stays glanceable.
  var detail: (Page) -> String? = { _ in nil }
  @ViewBuilder let panel: (Page) -> Panel

  @Environment(\.heliosTheme) private var theme
  @Environment(\.dynamicTypeSize) private var typeSize
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  private var index: Int { pages.firstIndex(of: selection) ?? 0 }

  var body: some View {
    VStack(spacing: HeliosTokens.space(3)) {
      panel(selection)
        .id(selection)
        .transition(.opacity)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .simultaneousGesture(swipe)
        .accessibilityElement(children: .combine)
        .accessibilityValue(Text(position(for: selection)))
        .accessibilityHint(Text("Swipe up or down to change page"))
        .accessibilityAdjustableAction { direction in
          switch direction {
          case .increment: step(1)
          case .decrement: step(-1)
          @unknown default: break
          }
        }
        .accessibilityAction(named: Text("Next page")) { step(1) }
        .accessibilityAction(named: Text("Previous page")) { step(-1) }
        .accessibilityIdentifier("\(identifier)-panel")
      tabs
      footer
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel(Text(cardName))
  }

  /// Named pages: one row when they fit, two columns when not, one column at AX sizes.
  @ViewBuilder private var tabs: some View {
    if typeSize.isAccessibilitySize {
      VStack(spacing: HeliosTokens.space(2)) {
        ForEach(pages) { page in tab(page) }
      }
    } else {
      ViewThatFits(in: .horizontal) {
        HStack(spacing: HeliosTokens.space(1)) {
          ForEach(pages) { page in tab(page) }
        }
        LazyVGrid(
          columns: [GridItem(.flexible()), GridItem(.flexible())],
          spacing: HeliosTokens.space(2)
        ) {
          ForEach(pages) { page in tab(page) }
        }
      }
    }
  }

  /// Selection shows as a filled tint, a stronger edge, bold text and the selected trait,
  /// never by colour alone. Surfaces are opaque so text contrast is the audited pair.
  private func tab(_ page: Page) -> some View {
    let selected = page == selection
    let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
    let value = detail(page)
    return Button {
      select(page)
    } label: {
      VStack(spacing: 0) {
        Text(verbatim: page.pageTitle)
          .heliosFont(selected ? .bodyStrong : .footnote)
          .foregroundStyle(
            selected ? theme.palette.text.primary.color : theme.palette.text.secondary.color)
        if let value {
          Text(verbatim: value)
            .heliosFont(.caption)
            .foregroundStyle(theme.palette.text.secondary.color)
        }
      }
      .multilineTextAlignment(.center)
      .fixedSize(horizontal: false, vertical: true)
      .padding(.horizontal, HeliosTokens.space(1))
      .padding(.vertical, HeliosTokens.space(1))
      .frame(maxWidth: .infinity, minHeight: 48)
      .background {
        shape.fill(
          selected ? theme.palette.accent.subtle.color : theme.palette.opaque.raised.color)
      }
      .overlay {
        shape.strokeBorder(
          selected ? theme.palette.accent.base.color : theme.palette.border.hairline.color,
          lineWidth: selected ? 1.5 : 1)
      }
      .contentShape(shape)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(
      value.map { Text("Show \(page.pageTitle), \($0)") } ?? Text("Show \(page.pageTitle)"))
    .accessibilityAddTraits(selected ? .isSelected : [])
    .accessibilityIdentifier("\(identifier)-page-\(page.id)")
  }

  /// Previous · "Protein · 2 of 4" · Next. The position text wraps between the buttons.
  private var footer: some View {
    HStack(spacing: HeliosTokens.space(2)) {
      stepButton(-1)
      Text(verbatim: "\(selection.pageTitle) · \(index + 1) / \(pages.count)")
        .heliosFont(.caption)
        .foregroundStyle(theme.palette.text.secondary.color)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
      stepButton(1)
    }
  }

  private func stepButton(_ offset: Int) -> some View {
    Button {
      step(offset)
    } label: {
      Image(systemName: offset < 0 ? "chevron.left" : "chevron.right")
        .foregroundStyle(theme.palette.text.primary.color)
        .frame(minWidth: 48, minHeight: 48)
        .background(theme.palette.opaque.raised.color, in: Circle())
        .overlay { Circle().strokeBorder(theme.palette.border.hairline.color, lineWidth: 1) }
        .contentShape(Circle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(Text(offset < 0 ? "Previous page" : "Next page"))
    .accessibilityIdentifier("\(identifier)-\(offset < 0 ? "previous" : "next")")
  }

  /// Horizontal drags on the panel only; a mostly vertical drag is left to the scroll view.
  private var swipe: some Gesture {
    DragGesture(minimumDistance: 28)
      .onEnded { drag in
        let horizontal = drag.translation.width
        guard abs(horizontal) >= 44, abs(horizontal) > abs(drag.translation.height) * 1.25
        else { return }
        step(horizontal < 0 ? 1 : -1)
      }
  }

  private func step(_ offset: Int) {
    guard !pages.isEmpty else { return }
    select(pages[(index + offset + pages.count) % pages.count])
  }

  private func select(_ page: Page) {
    guard page != selection else { return }
    // A short cross-fade, or none with Reduce Motion; nothing slides.
    withAnimation(reduceMotion ? nil : .easeInOut(duration: HeliosTokens.motion.fast)) {
      selection = page
    }
    AccessibilityNotification.Announcement(position(for: page)).post()
  }

  private func position(for page: Page) -> String {
    let number = (pages.firstIndex(of: page) ?? 0) + 1
    return String(localized: "\(page.pageTitle), page \(number) of \(pages.count)")
  }
}
