import HeliosDesign
import SwiftData
import SwiftUI

/// What the floating + button can log from anywhere (brief §1.2 Quick Log).
enum QuickLogAction: String, Identifiable {
  case food, checkIn, workout, dose
  var id: String { rawValue }
}

/// A short menu of the most common entries. Each choice closes the menu and opens the
/// same editor the owning screen uses, so there is one way to log each thing.
struct QuickLogSheet: View {
  let includesDose: Bool
  let choose: (QuickLogAction) -> Void
  @Environment(\.dismiss) private var dismiss
  @Environment(\.heliosTheme) private var theme

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: HeliosTokens.space(3)) {
          row(.food, "Food", detail: "Search, scan or pick a recent food", symbol: "fork.knife")
          row(.workout, "Workout", detail: "Start or continue today's session", symbol: "dumbbell")
          if includesDose {
            row(.dose, "Dose", detail: "Record a dose you have taken", symbol: "cross.vial")
          }
          row(
            .checkIn, "Weigh-in or note", detail: "Weight, photo or a note for today",
            symbol: "scalemass")
        }
        .padding()
      }
      .caliberScreen()
      .navigationTitle("Quick Log")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }.frame(minHeight: 48)
        }
      }
    }
    .presentationDetents([.medium, .large])
  }

  private func row(
    _ action: QuickLogAction, _ title: LocalizedStringKey, detail: LocalizedStringKey,
    symbol: String
  ) -> some View {
    Button {
      choose(action)
    } label: {
      HStack(spacing: HeliosTokens.space(3)) {
        Image(systemName: symbol)
          .foregroundStyle(theme.palette.accent.base.color)
          .frame(width: 40, height: 40)
          .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
              .fill(theme.palette.accent.subtle.color)
          )
          .accessibilityHidden(true)
        VStack(alignment: .leading, spacing: 2) {
          Text(title).heliosFont(.bodyStrong)
            .foregroundStyle(theme.palette.text.primary.color)
          Text(detail).heliosFont(.footnote)
            .foregroundStyle(theme.palette.text.secondary.color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        Image(systemName: "chevron.right")
          .foregroundStyle(theme.palette.text.tertiary.color)
          .accessibilityHidden(true)
      }
      .frame(minHeight: 48)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .glassCard(level: .base, cornerRadius: HeliosTokens.radius.tile)
    .accessibilityIdentifier("quickLog-" + action.rawValue)
  }
}

private struct CaliberProfileActionKey: EnvironmentKey {
  static let defaultValue: (() -> Void)? = nil
}

extension EnvironmentValues {
  var caliberProfileAction: (() -> Void)? {
    get { self[CaliberProfileActionKey.self] }
    set { self[CaliberProfileActionKey.self] = newValue }
  }
}

/// Own the sheet once per navigation stack. The header draws its button inline,
/// avoiding the OS toolbar's extra glass capsule and vertical gap.
private struct ProfileAvatarModifier: ViewModifier {
  @State private var showsProfile = false

  func body(content: Content) -> some View {
    content
      .environment(\.caliberProfileAction, { showsProfile = true })
      .sheet(isPresented: $showsProfile) { ProfileView(showsDone: true) }
  }
}

extension View {
  func profileAvatar() -> some View { modifier(ProfileAvatarModifier()) }
}
