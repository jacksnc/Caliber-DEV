import SwiftData
import SwiftUI

/// Reusable personal recipes and meals. Source ingredients and logged portions
/// are independent snapshots, so editing a recipe cannot rewrite the diary.
struct MyMealsView: View {
  @Environment(\.locale) private var locale
  @Environment(\.modelContext) private var context
  @Query(sort: \SavedMeal.name) private var savedMeals: [SavedMeal]
  @State private var creating = false
  @State private var editing: SavedMeal?
  @State private var deleting: SavedMeal?
  @State private var error: String?

  var body: some View {
    List {
      Group {
        if savedMeals.isEmpty {
          ContentUnavailableView(
            "No Saved Recipes or Meals", systemImage: "square.stack.3d.up",
            description: Text("Tap + to combine ingredients and save batch servings."))
        }
        ForEach(savedMeals) { meal in
          NavigationLink {
            SavedMealDetailView(meal: meal)
          } label: {
            VStack(alignment: .leading, spacing: 4) {
              Text(meal.name)
              if let batch = try? RecipeEditor.batch(for: meal),
                let serving = try? batch.portion(amount: 1, unit: .servings)
              {
                Text(
                  "\(NutritionInput.format(serving.calories, locale: locale)) cal per serving · \(NutritionInput.format(meal.servings, locale: locale)) servings"
                )
                .font(.footnote).foregroundStyle(.secondary)
              } else {
                Text("Needs ingredient review").font(.footnote)
              }
            }.frame(minHeight: 48)
          }.accessibilityIdentifier("savedRecipe-" + meal.name)
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
              Button("Delete", role: .destructive) { deleting = meal }
              Button("Edit") { editing = meal }.tint(.blue)
            }
        }
      }
      .listRowBackground(CaliberRowBackground())
    }
    .caliberScreen()
    .navigationTitle("My Meals")
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button {
          creating = true
        } label: {
          Label("Create Recipe or Meal", systemImage: "plus")
        }
        .accessibilityIdentifier("createRecipe")
      }
    }
    .sheet(isPresented: $creating) { RecipeEditorView() }
    .sheet(item: $editing) { RecipeEditorView(meal: $0) }
    .confirmationDialog(
      "Delete saved recipe or meal?",
      isPresented: Binding(
        get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible
    ) {
      Button("Delete Saved Meal", role: .destructive) {
        guard let deleting else { return }
        do { try RecipeEditor.delete(meal: deleting, in: context) } catch {
          self.error = error.localizedDescription
        }
        self.deleting = nil
      }
    } message: {
      Text("Foods already logged in your diary stay unchanged.")
    }
    .alert(
      "Couldn't Update Meal",
      isPresented: Binding(
        get: { error != nil }, set: { if !$0 { error = nil } })
    ) {
      Button("OK", role: .cancel) { error = nil }
    } message: {
      Text(error ?? "Please try again.")
    }
  }
}
