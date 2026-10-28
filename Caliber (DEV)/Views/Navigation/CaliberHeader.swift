import HeliosDesign
import SwiftUI

/// The look book places the avatar beside the title, inside the content header.
/// It must not reserve a second, empty navigation bar above that header.
struct CaliberHeader: View {
  let title: LocalizedStringKey
  var overline: Text?
  var identifier: String
  var showsProfile: Bool
  var action: (() -> Void)?
  var actionLabel: LocalizedStringKey
  var actionIdentifier: String
  @Environment(\.heliosTheme) private var theme
  @Environment(\.caliberProfileAction) private var openProfile

  init(
    _ title: LocalizedStringKey, identifier: String, overline: Text? = nil,
    showsProfile: Bool = true, action: (() -> Void)? = nil,
    actionLabel: LocalizedStringKey = "Add", actionIdentifier: String = ""
  ) {
    self.title = title
    self.identifier = identifier
    self.overline = overline
    self.showsProfile = showsProfile
    self.action = action
    self.actionLabel = actionLabel
    self.actionIdentifier = actionIdentifier
  }

  var body: some View {
    HStack(alignment: .bottom, spacing: HeliosTokens.space(2)) {
      VStack(alignment: .leading, spacing: 2) {
        if let overline {
          overline.heliosFont(.footnote)
            .foregroundStyle(theme.palette.text.secondary.color)
        }
        Text(title)
          .font(.system(.title, design: .rounded, weight: .medium))
          .foregroundStyle(theme.palette.text.primary.color)
          .fixedSize(horizontal: false, vertical: true)
          .accessibilityAddTraits(.isHeader)
          .accessibilityIdentifier("screenTitle-" + identifier)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      if let action {
        Button(action: action) {
          Image(systemName: "plus")
            .resizable()
            .scaledToFit()
            .frame(width: 18, height: 18)
            .frame(width: 44, height: 44)
            .foregroundStyle(theme.palette.accent.base.color)
            .background { GlassBackground(level: .raised, cornerRadius: 22) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(actionLabel))
        .accessibilityIdentifier(actionIdentifier)
      }
      if showsProfile, let openProfile {
        Button(action: openProfile) {
          Image(systemName: "person")
            .resizable()
            .scaledToFit()
            .fontWeight(.medium)
            .frame(width: 20, height: 20)
            .foregroundStyle(theme.palette.text.primary.color)
            .frame(width: 44, height: 44)
            .background { GlassBackground(level: .raised, cornerRadius: 22) }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Profile and Settings")
        .accessibilityIdentifier("openProfile")
      }
    }
    .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
  }
}

extension View {
  /// Primary screens draw their own header. Pushed destinations can retain the
  /// system back button without duplicating the visible title.
  func compactNavigationTitle(_ title: LocalizedStringKey, hidesBar: Bool = true) -> some View {
    navigationTitle(title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar(hidesBar ? .hidden : .visible, for: .navigationBar)
      .toolbar {
        ToolbarItem(placement: .principal) {
          Color.clear.frame(width: 1, height: 1).accessibilityHidden(true)
        }
      }
  }

  func caliberSectionHeader() -> some View {
    textCase(nil)
      .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: HeliosTokens.space(2), trailing: 0))
  }

  func caliberHeaderRow() -> some View {
    listRowBackground(Color.clear)
      .listRowSeparator(.hidden)
      .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 4, trailing: 4))
  }

  /// A complete chart/card owns its padding, corners and lit edge. Native row
  /// padding must not turn it into a small card inside an opaque list cell.
  func caliberCardRow() -> some View {
    glassCard()
      .listRowInsets(EdgeInsets())
      .listRowBackground(Color.clear)
      .listRowSeparator(.hidden)
  }
}
