import CaliberDatabase
import SwiftData
import SwiftUI

/// Imported menu rows are immutable values. Personal additions remain editable
/// in the existing restaurant store, and diary logs receive independent copies.
struct ImportedRestaurantMenuView: View {
  @Environment(\.modelContext) private var context
  @Query(sort: \Restaurant.name) private var personalRestaurants: [Restaurant]
  let restaurant: RestaurantMenuCatalogRestaurant
  let source: RestaurantMenuCatalogSource
  let fictional: Bool
  let mealType: MealType
  let date: Date
  @State private var search = ""
  @State private var addingTo: Restaurant?
  @State private var editing: MenuItem?
  @State private var error: String?

  private var personal: Restaurant? {
    personalRestaurants.first {
      FoodSearchText.normalized($0.name) == FoodSearchText.normalized(restaurant.name)
    }
  }
  private var customItems: [MenuItem] {
    (personal?.menuItems ?? []).filter {
      $0.isCustom && FoodSearchText.matches($0.name, query: search)
    }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
  }

  var body: some View {
    List {
      Section("Menu Information") {
        if fictional { Text("Fictional test menu").accessibilityIdentifier("fictionalMenuNotice") }
        Text("Source: \(source.name) · Retrieved \(source.retrievedOn)").font(.footnote)
        Text("Compare the serving with your order. Your logged nutrition can be edited.").font(
          .footnote)
        Link("View Nutrition Source", destination: URL(string: source.url)!).frame(minHeight: 48)
      }
      ForEach(MenuCategory.displayOrder) { category in
        let items = restaurant.items.filter {
          $0.category == category.rawValue && FoodSearchText.matches($0.name, query: search)
        }
        if !items.isEmpty {
          Section(category.displayName) {
            ForEach(items, id: \.id) { item in
              NavigationLink {
                FoodNutritionReviewView(
                  reference: BundledRestaurantMenuService.reference(
                    item: item, restaurant: restaurant, source: source),
                  meal: mealType, date: date)
              } label: {
                VStack(alignment: .leading, spacing: 4) {
                  Text(item.name)
                  Text(item.servingDescription).font(.footnote).foregroundStyle(.secondary)
                }.frame(minHeight: 48)
              }.accessibilityIdentifier("importedMenu-" + item.id)
            }
          }
        }
      }
      if !customItems.isEmpty {
        Section("My Custom Items") {
          ForEach(customItems) { item in
            NavigationLink {
              MenuItemDetailView(menuItem: item, mealType: mealType, date: date)
            } label: {
              Text(item.name).frame(minHeight: 48)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
              Button("Delete", role: .destructive) {
                do { try CustomMenuItemEditor.delete(item: item, in: context) } catch {
                  self.error = error.localizedDescription
                }
              }
              Button("Edit") { editing = item }.tint(.blue)
            }
          }
        }
      }
    }
    .navigationTitle(restaurant.name)
    .searchable(text: $search, prompt: "Search this menu")
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button {
          do {
            addingTo =
              try personal ?? CustomRestaurantEditor.create(name: restaurant.name, in: context)
          } catch { self.error = error.localizedDescription }
        } label: {
          Label("Add Custom Item", systemImage: "plus")
        }
      }
    }
    .sheet(item: $addingTo) { AddMenuItemView(restaurant: $0) }
    .sheet(item: $editing) { item in
      if let personal { AddMenuItemView(restaurant: personal, item: item) }
    }
    .alert(
      "Couldn't Update Menu",
      isPresented: Binding(
        get: { error != nil }, set: { if !$0 { error = nil } })
    ) {
      Button("OK", role: .cancel) { error = nil }
    } message: {
      Text(error ?? "Please try again.")
    }
  }
}
