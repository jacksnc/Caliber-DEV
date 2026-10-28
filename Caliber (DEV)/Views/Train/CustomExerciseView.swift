import SwiftData
import SwiftUI

/// Used by both the library and the live workout picker. Cancel edits only a
/// draft; successful creation can notify the picker to add the saved exercise.
struct CustomExerciseView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  @State private var name: String
  @State private var aliases = ""
  @State private var message: String?
  private let onSave: ((TrainingExercise) -> Void)?

  init(initialName: String = "", onSave: ((TrainingExercise) -> Void)? = nil) {
    _name = State(initialValue: initialName)
    self.onSave = onSave
  }

  private var canSave: Bool {
    !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField(String(localized: "Name", table: "CustomExercises"), text: $name)
            .accessibilityIdentifier("customExerciseName")
          TextField(
            String(localized: "Aliases (optional)", table: "CustomExercises"), text: $aliases
          )
          .accessibilityIdentifier("customExerciseAliases")
          LabeledContent {
            Text("Weight × reps", tableName: "CustomExercises")
          } label: {
            Text("Logging style", tableName: "CustomExercises")
          }
          Text(
            "Your exercise will be saved in your library and can be used in future workouts.",
            tableName: "CustomExercises"
          )
          .font(.footnote)
          .foregroundStyle(.secondary)
        } header: {
          Text("Exercise", tableName: "CustomExercises")
        }
        .listRowBackground(CaliberRowBackground())
      }
      .caliberScreen()
      .navigationTitle(Text("Custom Exercise", tableName: "CustomExercises"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button {
            dismiss()
          } label: {
            Text("Cancel", tableName: "CustomExercises")
          }
          .accessibilityIdentifier("customExerciseCancel")
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(action: save) { Text("Save", tableName: "CustomExercises") }
            .disabled(!canSave)
            .accessibilityIdentifier("customExerciseSave")
        }
      }
      .alert(
        Text("Couldn't Save Exercise", tableName: "CustomExercises"),
        isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })
      ) {
        Button {
          message = nil
        } label: {
          Text("OK", tableName: "CustomExercises")
        }
      } message: {
        Text(message ?? "")
      }
    }
  }

  private func save() {
    do {
      let exercise = try CustomExerciseEditor.create(name: name, aliases: aliases, in: modelContext)
      onSave?(exercise)
      dismiss()
    } catch let error as CustomExerciseError {
      message = error.localizedDescription
    } catch {
      message = String(
        localized: "The custom exercise could not be saved. Please try again.",
        table: "CustomExercises")
    }
  }
}
