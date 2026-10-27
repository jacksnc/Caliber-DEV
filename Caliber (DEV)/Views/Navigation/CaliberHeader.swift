import HeliosDesign
import SwiftUI

/// The look book's screen header: an optional small overline above a compact title, drawn
/// in the content instead of the system large title.
struct CaliberHeader: View {
  let title: LocalizedStringKey
  var overline: Text?
  var identifier: String
  @Environment(\.heliosTheme) private var theme

  init(_ title: LocalizedStringKey, identifier: String, overline: Text? = nil) {
    self.title = title
    self.identifier = identifier
    self.overline = overline
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      if let overline {
        overline
          .heliosFont(.footnote)
          .foregroundStyle(theme.palette.text.secondary.color)
      }
      Text(title)
        .font(.title.weight(.medium))
        .foregroundStyle(theme.palette.text.primary.color)
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("screenTitle-" + identifier)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

extension View {
  /// Keeps the navigation title for VoiceOver and back buttons, but leaves the bar empty so
  /// the screen can draw `CaliberHeader` itself.
  func compactNavigationTitle(_ title: LocalizedStringKey) -> some View {
    navigationTitle(title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .principal) {
          Color.clear.frame(width: 1, height: 1).accessibilityHidden(true)
        }
      }
  }

  /// The screen header on a `List`, as its first section's header: a header is not clipped
  /// to the section's rounded shape the way a row is, and sits at the top of the list.
  func caliberSectionHeader() -> some View {
    textCase(nil)
      .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: HeliosTokens.space(2), trailing: 4))
  }

  /// A full-width row without a card, such as a closing button.
  func caliberHeaderRow() -> some View {
    listRowBackground(Color.clear)
      .listRowSeparator(.hidden)
      .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 4, trailing: 4))
  }
}
