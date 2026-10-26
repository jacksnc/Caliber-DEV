import SwiftData
import SwiftUI

struct AddRestaurantView: View {
  @Environment(\.modelContext) private var context
  @Environment(\.dismiss) private var dismiss
  @State private var name = ""
  @State private var error: String?

  var body: some View {
    NavigationStack {
      Form {
        Group {
          Section {
            TextField("Restaurant Name", text: $name).textInputAutocapitalization(.words)
              .accessibilityIdentifier("newRestaurantName")
          } header: {
            Text("Restaurant")
          } footer: {
            Text(
              "Add a local restaurant or another location, then create your own menu items from its nutrition information."
            )
          }
          if let error { Text(error).foregroundStyle(.secondary) }
        }
        .listRowBackground(CaliberRowBackground())
      }
      .caliberScreen()
      .navigationTitle("Add Restaurant")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            do {
              _ = try CustomRestaurantEditor.create(name: name, in: context)
              dismiss()
            } catch { self.error = error.localizedDescription }
          }.disabled(FoodSearchText.normalized(name).isEmpty || name.count > 100)
            .accessibilityIdentifier("saveRestaurant")
        }
      }
    }
  }
}
