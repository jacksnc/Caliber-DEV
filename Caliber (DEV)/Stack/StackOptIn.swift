import HeliosDesign
import SwiftUI

/// Settings → Modules. Stack stays hidden until the person reads the scope and turns it on
/// (brief §5.1, §11.3), and can be hidden or erased at any time.
struct StackSettingsSection: View {
  @EnvironmentObject private var stack: StackRuntime
  @State private var showsOptIn = false
  @State private var confirmsDelete = false
  @State private var message: String?

  var body: some View {
    if stack.isAllowed {
      Section {
        Toggle(
          "Stack",
          isOn: Binding(
            get: { stack.isEnabled },
            set: { turnOn in
              if turnOn { showsOptIn = true } else { stack.disable() }
            })
        )
        .accessibilityIdentifier("stackModuleToggle")
        .sheet(isPresented: $showsOptIn) { StackOptInView() }
        if stack.isEnabled {
          Toggle("Lock Stack with Face ID or Passcode", isOn: $stack.requiresUnlock)
            .accessibilityIdentifier("stackLockToggle")
          Toggle("Illustrative Estimate (Preview)", isOn: $stack.showsEstimate)
            .accessibilityIdentifier("stackEstimateToggle")
        }
        Button("Delete Stack Data", role: .destructive) { confirmsDelete = true }
          .frame(minHeight: 48)
          .confirmationDialog(
            "Delete every Stack entry on this device?", isPresented: $confirmsDelete,
            titleVisibility: .visible
          ) {
            Button("Delete Stack Data", role: .destructive, action: deleteAll)
          }
        if let message {
          Text(message).font(.footnote)
        }
      } header: {
        Text("Modules")
      } footer: {
        Text(
          "Stack is a private logbook for medications, peptides and supplements. Turning it off hides it and keeps your entries until you delete them. The illustrative estimate is a preview that stays off until you turn it on; it is not a blood level."
        )
      }
    }
  }

  private func deleteAll() {
    do {
      try stack.deleteAllData()
      message = "Stack data deleted."
    } catch {
      message = "Stack data could not be deleted. Try again."
    }
  }
}

/// The opt-in: what Stack is, what it never does, and how it is kept private.
struct StackOptInView: View {
  @EnvironmentObject private var stack: StackRuntime
  @Environment(\.dismiss) private var dismiss
  @Environment(\.heliosTheme) private var theme
  @State private var understood = false

  var body: some View {
    NavigationStack {
      Form {
        Group {
          Section {
            Text("A private logbook for what you take").heliosFont(.title)
            point(
              "list.clipboard",
              "Records the medications, peptides and supplements you enter, with your own amounts and schedules."
            )
            point(
              "hand.raised",
              "Never suggests a dose, timing, combination or source, and makes no claims about effects."
            )
            point(
              "lock.shield",
              "Kept in a separate store on this device, excluded from backups, and locked with Face ID or your passcode."
            )
            point(
              "stethoscope",
              "Not medical advice. Talk to a licensed clinician about medical decisions.")
          }
          Section {
            Toggle("I understand Stack is a logbook, not medical advice", isOn: $understood)
              .accessibilityIdentifier("stackScopeConfirmation")
            Button("Turn On Stack") {
              stack.enable()
              dismiss()
            }
            .disabled(!understood)
            .frame(minHeight: 48)
            .accessibilityIdentifier("stackTurnOn")
          }
        }
        .listRowBackground(CaliberRowBackground())
      }
      .caliberScreen()
      .navigationTitle("Stack")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
      }
    }
  }

  private func point(_ symbol: String, _ text: LocalizedStringKey) -> some View {
    Label {
      Text(text).heliosFont(.callout)
    } icon: {
      Image(systemName: symbol).foregroundStyle(theme.palette.accent.base.color)
    }
  }
}
