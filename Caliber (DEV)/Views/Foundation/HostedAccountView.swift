import CaliberIntegrations
import SwiftUI

struct HostedAccountView: View {
  @EnvironmentObject private var account: HostedAccountModel
  @State private var email = ""
  @State private var password = ""
  @AccessibilityFocusState private var messageIsFocused: Bool

  var body: some View {
    Form {
      Section("Account") {
        if !account.isAvailable {
          Label("Hosted setup pending", systemImage: "cloud")
          Text(
            account.project == nil
              ? "Account setup is unavailable. Reopen the app after checking its configuration."
              : "Your Supabase project is selected. Sign-in becomes available after the backend is deployed and verified."
          )
        } else if account.isSignedIn {
          Label("Signed in", systemImage: "person.crop.circle.badge.checkmark")
            .accessibilityIdentifier("accountSignedIn")
          Button {
            Task { await account.signOut() }
          } label: {
            Text("Sign Out on This Device").frame(minHeight: 48)
          }.disabled(account.isBusy).accessibilityIdentifier("accountSignOut")
        } else {
          TextField("Email", text: $email)
            .textContentType(.username).keyboardType(.emailAddress)
            .textInputAutocapitalization(.never).autocorrectionDisabled()
            .accessibilityIdentifier("accountEmail")
          SecureField("Password", text: $password)
            .textContentType(.password).accessibilityIdentifier("accountPassword")
          Button {
            let submittedPassword = password
            password = ""
            Task { await account.signIn(email: email, password: submittedPassword) }
          } label: {
            Text("Sign In").frame(minHeight: 48)
          }.disabled(
            account.isBusy || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
              || password.isEmpty
          )
          .accessibilityIdentifier("accountSignIn")
          Text("Use an existing Caliber account. Your Supabase dashboard login is separate.").font(
            .footnote)
        }
        if account.restoreFailed {
          Button {
            Task { await account.restore() }
          } label: {
            Text("Try Checking Account Again").frame(minHeight: 48)
          }.disabled(account.isBusy)
          Button {
            Task { await account.signOut() }
          } label: {
            Text("Remove Saved Session").frame(minHeight: 48)
          }.disabled(account.isBusy)
        }
        if account.isBusy { ProgressView("Checking account…") }
        if let message = account.message {
          Text(message).accessibilityIdentifier("accountMessage")
            .accessibilityFocused($messageIsFocused)
        }
      }
      Section("Storage") {
        Text(
          "Your diary, photos, weight and notes remain on this device. Signing in does not start cloud backup."
        )
        if let project = account.project {
          LabeledContent("Server Region", value: project.region)
          Text("Account access is handled by your Caliber backend on Supabase.").font(.footnote)
        }
      }
    }
    .navigationTitle("Account")
    .task { await account.restore() }
    .onDisappear { password = "" }
    .onChange(of: account.message) { _, message in
      if message != nil { messageIsFocused = true }
    }
  }
}
