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

/// The round profile button at the top right of every primary screen. Settings live
/// inside Profile (brief §1.2: "Settings behind the profile avatar").
private struct ProfileAvatarModifier: ViewModifier {
  @State private var showsProfile = false
  @Environment(\.heliosTheme) private var theme

  func body(content: Content) -> some View {
    content
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            showsProfile = true
          } label: {
            Image(systemName: "person")
              .fontWeight(.medium)
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
      .sheet(isPresented: $showsProfile) { ProfileView(showsDone: true) }
  }
}

extension View {
  func profileAvatar() -> some View { modifier(ProfileAvatarModifier()) }
}
