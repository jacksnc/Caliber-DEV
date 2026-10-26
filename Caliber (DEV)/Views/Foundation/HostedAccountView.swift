import CaliberIntegrations
import SwiftUI

struct HostedAccountView: View {
  @EnvironmentObject private var account: HostedAccountModel
  @State private var email = ""
  @State private var password = ""
  @State private var consentChecked = false
  @State private var showingRecovery = false
  @State private var showingDeletion = false
  @AccessibilityFocusState private var messageIsFocused: Bool

  var body: some View {
    Form {
      Group {
        if let message = account.message {
          Section {
            Text(message).accessibilityIdentifier("accountMessage")
              .accessibilityFocused($messageIsFocused)
          }
        }
        Section("Account") {
          if !account.isAvailable {
            Label("Hosted setup pending", systemImage: "cloud")
            Text(
              "Account access is being verified. Your local diary and progress tracking are available."
            )
          } else if !account.hasAccountConsent {
            Text("Account access is optional").font(.headline)
            Text(
              "Your email and account requests are sent to Caliber's backend on Supabase. Passwords and recovery codes are used to authenticate you. Supabase may retain security logs under its provider policies."
            )
            Text(
              "Your diary, photos, weight and notes stay on this device. This permission does not enable personal cloud backup, AI uploads or analytics."
            )
            Text(
              "Caliber saves the permission version and date. You can stop account services here or delete your hosted account. Local logging works without an account."
            )
            Toggle("I want to use account services", isOn: $consentChecked)
              .accessibilityIdentifier("accountConsent")
            Button("Continue to Account") {
              account.acceptAccountConsent()
              Task { await account.restore() }
            }.disabled(!consentChecked || account.isBusy)
              .frame(minHeight: 48).accessibilityIdentifier("accountConsentContinue")
          } else if account.isSignedIn {
            Label("Signed in", systemImage: "person.crop.circle.badge.checkmark")
              .accessibilityIdentifier("accountSignedIn")
            Button("Sign Out on This Device") {
              Task { await account.signOut() }
            }.disabled(account.isBusy).frame(minHeight: 48).accessibilityIdentifier(
              "accountSignOut")
            Button("Delete Hosted Account", role: .destructive) { showingDeletion = true }
              .disabled(account.isBusy).frame(minHeight: 48).accessibilityIdentifier(
                "accountDelete")
          } else {
            TextField("Email", text: $email)
              .textContentType(.username).keyboardType(.emailAddress)
              .textInputAutocapitalization(.never).autocorrectionDisabled()
              .accessibilityIdentifier("accountEmail")
            SecureField("Password", text: $password)
              .textContentType(.password).accessibilityIdentifier("accountPassword")
            Button("Sign In") {
              let submittedPassword = password
              password = ""
              Task { await account.signIn(email: email, password: submittedPassword) }
            }.disabled(
              account.isBusy || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || password.isEmpty
            )
            .frame(minHeight: 48).accessibilityIdentifier("accountSignIn")
            Button("Forgot Password?") {
              password = ""
              showingRecovery = true
            }
            .disabled(account.isBusy).frame(minHeight: 48).accessibilityIdentifier("accountRecover")
            Text("Use an existing Caliber account. Your Supabase dashboard login is separate.")
              .font(
                .footnote)
          }
          if account.restoreFailed {
            Button("Try Checking Account Again") { Task { await account.restore() } }
              .disabled(account.isBusy).frame(minHeight: 48)
          }
          if account.restoreFailed || account.sessionRemovalPending {
            Button("Remove Saved Session") { Task { await account.signOut() } }
              .disabled(account.isBusy).frame(minHeight: 48).accessibilityIdentifier(
                "accountRemoveSession")
          }
          if account.isBusy { ProgressView("Checking account…") }
        }
        Section("Storage") {
          Text(
            "Your diary, photos, weight and notes remain on this device. Signing in does not start cloud backup."
          )
          if let project = account.project {
            LabeledContent("Server Region", value: project.region)
            Text("Account access is handled by your Caliber backend on Supabase.").font(.footnote)
          }
          if account.hasAccountConsent {
            Button("Stop Using Account Services") { Task { await account.stopAccountServices() } }
              .disabled(account.isBusy).frame(minHeight: 48).accessibilityIdentifier(
                "accountStopServices")
            Text(
              "This removes permission and the saved session from this device. It does not delete the hosted account or other devices' sessions."
            ).font(.footnote)
          }
        }
      }
      .listRowBackground(CaliberRowBackground())
    }
    .caliberScreen()
    .navigationTitle("Account")
    .task { await account.restore() }
    .sheet(isPresented: $showingRecovery) { PasswordRecoveryView(initialEmail: email) }
    .sheet(isPresented: $showingDeletion) { AccountDeletionView() }
    .onDisappear { password = "" }
    .onChange(of: account.message) { _, message in if message != nil { messageIsFocused = true } }
    .onChange(of: account.hasAccountConsent) { _, hasConsent in
      if !hasConsent { consentChecked = false }
    }
  }
}

private struct PasswordRecoveryView: View {
  @EnvironmentObject private var account: HostedAccountModel
  @Environment(\.dismiss) private var dismiss
  @State private var email: String
  @State private var code = ""
  @State private var newPassword = ""
  @State private var repeatedPassword = ""
  init(initialEmail: String) { _email = State(initialValue: initialEmail) }
  var body: some View {
    NavigationStack {
      Form {
        Group {
          Section {
            Text(
              "Request a code, then enter it here with a new password. Recovery does not sign you in or upload your logs."
            )
            TextField("Email", text: $email).textContentType(.username).keyboardType(.emailAddress)
              .textInputAutocapitalization(.never).autocorrectionDisabled()
              .accessibilityIdentifier("recoveryEmail")
            Button("Send Recovery Code") {
              Task { await account.requestPasswordRecovery(email: email) }
            }
            .disabled(
              account.isBusy || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
            .frame(minHeight: 48).accessibilityIdentifier("recoverySend")
          }
          Section("Set a New Password") {
            TextField("Recovery Code", text: $code).textContentType(.oneTimeCode).keyboardType(
              .numberPad
            )
            .accessibilityIdentifier("recoveryCode")
            SecureField("New Password", text: $newPassword).textContentType(.newPassword)
              .accessibilityIdentifier("recoveryNewPassword")
            SecureField("Repeat New Password", text: $repeatedPassword).textContentType(
              .newPassword
            )
            .accessibilityIdentifier("recoveryRepeatPassword")
            Text("Use at least 8 characters. Never share a recovery code.").font(.footnote)
            Button("Change Password") {
              let submittedCode = code
              let submittedPassword = newPassword
              code = ""
              newPassword = ""
              repeatedPassword = ""
              Task {
                await account.resetPassword(
                  email: email, code: submittedCode, newPassword: submittedPassword)
              }
            }.disabled(
              account.isBusy || email.isEmpty || !(6...10).contains(code.count)
                || !code.allSatisfy({ $0.isASCII && $0.isNumber }) || newPassword.count < 8
                || newPassword != repeatedPassword
            )
            .frame(minHeight: 48).accessibilityIdentifier("recoveryChangePassword")
          }
          if account.isBusy { ProgressView("Checking account…") }
          if let message = account.message {
            Text(message).accessibilityIdentifier("recoveryMessage")
          }
        }
        .listRowBackground(CaliberRowBackground())
      }
      .caliberScreen()
      .navigationTitle("Password Recovery")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Done") { dismiss() }.disabled(account.isBusy)
        }
      }
      .interactiveDismissDisabled(account.isBusy)
      .onDisappear {
        code = ""
        newPassword = ""
        repeatedPassword = ""
      }
    }
  }
}

private struct AccountDeletionView: View {
  @EnvironmentObject private var account: HostedAccountModel
  @Environment(\.dismiss) private var dismiss
  @State private var password = ""
  @State private var confirmation = ""
  @State private var confirming = false
  var body: some View {
    NavigationStack {
      Form {
        Group {
          Section {
            Text(
              "This permanently deletes your hosted account and its Caliber server records. It cannot be undone. Provider logs and backups follow their retention policies."
            )
            Text(
              "Your local diary, progress photos, weight and notes stay on this device. Deleting the hosted account does not erase local copies on other devices."
            )
            SecureField("Current Password", text: $password).textContentType(.password)
              .accessibilityIdentifier("deletionPassword")
            TextField("Type DELETE to confirm", text: $confirmation)
              .textInputAutocapitalization(.characters).autocorrectionDisabled()
              .accessibilityIdentifier("deletionConfirmation")
            Button("Delete Hosted Account", role: .destructive) { confirming = true }
              .disabled(account.isBusy || password.isEmpty || confirmation != "DELETE")
              .frame(minHeight: 48).accessibilityIdentifier("deletionSubmit")
          }
          if account.isBusy { ProgressView("Deleting account…") }
          if let message = account.message {
            Text(message).accessibilityIdentifier("deletionMessage")
          }
        }
        .listRowBackground(CaliberRowBackground())
      }
      .caliberScreen()
      .navigationTitle("Delete Account")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }.disabled(account.isBusy)
        }
      }
      .interactiveDismissDisabled(account.isBusy)
      .confirmationDialog(
        "Permanently delete the hosted account?", isPresented: $confirming,
        titleVisibility: .visible
      ) {
        Button("Permanently Delete Account", role: .destructive) {
          let submitted = password
          password = ""
          confirmation = ""
          Task {
            await account.deleteAccount(password: submitted)
            if !account.isSignedIn { dismiss() }
          }
        }
        Button("Cancel", role: .cancel) {}
      }
      .onDisappear {
        password = ""
        confirmation = ""
      }
    }
  }
}
