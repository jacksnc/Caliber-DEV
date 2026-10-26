//
//  RestaurantDetailView.swift
//  Caliber (DEV)
//

import SwiftData
import SwiftUI

/// Built-in and personal menu items grouped into categories. Each choice opens a personal
/// portion/nutrition review before anything is added to the diary.
struct RestaurantDetailView: View {
  @Environment(\.locale) private var locale
  @Environment(\.modelContext) private var modelContext
  let restaurant: Restaurant
  let mealType: MealType
  let date: Date
  init(restaurant: Restaurant, mealType: MealType = .snack, date: Date = .now) {
    self.restaurant = restaurant
    self.mealType = mealType
    self.date = date
  }

  @State private var searchText = ""
  @State private var isAddingCustomItem = false
  @State private var editingCustomItem: MenuItem?
  @State private var menuError: String?

  private var query: String {
    searchText.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var filteredTemplates: [BuildableItemTemplate] {
    restaurant.buildableTemplates.filter { template in
      let labels =
        [restaurant.name, template.name]
        + template.categories.flatMap {
          [$0.name] + $0.options.map(\.name)
        }
      return FoodSearchText.matches(labels.joined(separator: " "), query: query)
    }
    .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
  }

  private var groupedMenuItems: [RestaurantMenuGroup] {
    MenuCategory.displayOrder.compactMap { category -> RestaurantMenuGroup? in
      let items = restaurant.menuItems.filter {
        $0.category == category
          && (query.isEmpty
            || FoodSearchText.matches(
              "\(restaurant.name) \($0.name) \(category.displayName)", query: query))
      }
      .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
      return items.isEmpty ? nil : RestaurantMenuGroup(category: category, items: items)
    }
  }

  var body: some View {
    List {
      // Each part is its own property: one builder holding the whole list is more than
      // Xcode 16 can type-check, and it then reports a misleading Charts error.
      Group {
        sourceSection
        emptyState
        templatesSection
        menuSections
        footerSection
      }
      .listRowBackground(CaliberRowBackground())
    }
    .caliberScreen()
    .navigationTitle(restaurant.name)
    .searchable(text: $searchText, prompt: "Search this menu")
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button {
          isAddingCustomItem = true
        } label: {
          Label("Add Custom Item", systemImage: "plus")
        }
      }
    }
    .sheet(isPresented: $isAddingCustomItem) {
      AddMenuItemView(restaurant: restaurant)
    }
    .sheet(item: $editingCustomItem) { item in
      AddMenuItemView(restaurant: restaurant, item: item)
    }
    .alert(
      "Couldn't Delete Item",
      isPresented: Binding(
        get: { menuError != nil },
        set: { if !$0 { menuError = nil } }
      )
    ) {
      Button("OK", role: .cancel) { menuError = nil }
    } message: {
      Text(menuError ?? "Please try again.")
    }
  }

  @ViewBuilder private var sourceSection: some View {
    if let source = RestaurantSourceDirectory.nutritionURL(for: restaurant.name) {
      Section("Menu Information") {
        Text(
          "Built-in values are samples, not a complete verified menu. Check the current restaurant information and adjust your log."
        ).font(.footnote)
        Link("Open Official Nutrition", destination: source).frame(minHeight: 48)
      }
    }
  }

  @ViewBuilder private var emptyState: some View {
    if filteredTemplates.isEmpty && groupedMenuItems.isEmpty {
      if query.isEmpty {
        ContentUnavailableView(
          "No Menu Items", systemImage: "fork.knife",
          description: Text("Tap + to add a custom item to this restaurant."))
      } else {
        ContentUnavailableView.search(text: searchText)
      }
    }
  }

  @ViewBuilder private var templatesSection: some View {
    if !filteredTemplates.isEmpty {
      Section("Build Your Own") {
        ForEach(filteredTemplates) { template in
          NavigationLink(template.name) {
            BuildYourOwnView(template: template, mealType: mealType, date: date)
          }
        }
      }
    }
  }

  @ViewBuilder private var menuSections: some View {
    ForEach(groupedMenuItems) { (group: RestaurantMenuGroup) in
      RestaurantMenuSection(
        group: group, mealType: mealType, date: date,
        onDelete: deleteCustomItem, onEdit: { editingCustomItem = $0 })
    }
  }

  @ViewBuilder private var footerSection: some View {
    Section {
    } footer: {
      Text(
        "Tap an item to review servings and edit your macros. Swipe left on a custom item to edit or delete it. Built-in nutrition is sample data until verified menus are available."
      )
    }
  }

  private func deleteCustomItem(_ item: MenuItem) {
    do {
      try CustomMenuItemEditor.delete(item: item, in: modelContext)
    } catch {
      menuError = error.localizedDescription
    }
  }
}

/// The menu items in one category. A named type rather than a tuple, so nothing about the
/// nested lists below is left for the compiler to infer (D108).
private struct RestaurantMenuGroup: Identifiable {
  let category: MenuCategory
  let items: [MenuItem]
  var id: MenuCategory { category }
}

/// One category section. Its rows are keyed by `persistentModelID` because `MenuItem` also
/// declares its own `id`, and Xcode 16.4 does not settle which one `Identifiable` means (D108).
private struct RestaurantMenuSection: View {
  let group: RestaurantMenuGroup
  let mealType: MealType
  let date: Date
  let onDelete: (MenuItem) -> Void
  let onEdit: (MenuItem) -> Void

  var body: some View {
    Section {
      ForEach(group.items, id: \.persistentModelID) { (item: MenuItem) in
        RestaurantMenuItemRow(
          item: item, mealType: mealType, date: date,
          onDelete: { onDelete(item) }, onEdit: { onEdit(item) })
      }
    } header: {
      Text(group.category.displayName)
    }
  }
}

/// One menu item. It is its own view so Xcode 16.4 type-checks it separately (D108).
private struct RestaurantMenuItemRow: View {
  @Environment(\.locale) private var locale
  let item: MenuItem
  let mealType: MealType
  let date: Date
  let onDelete: () -> Void
  let onEdit: () -> Void

  var body: some View {
    NavigationLink {
      MenuItemDetailView(menuItem: item, mealType: mealType, date: date)
    } label: {
      VStack(alignment: .leading, spacing: 2) {
        HStack {
          Text(item.name)
          if item.isCustom {
            Text("Custom")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
        Text(
          "\(NutritionInput.format(item.baseCalories, locale: locale)) cal · \(NutritionInput.format(item.baseProtein, locale: locale))p \(NutritionInput.format(item.baseCarbs, locale: locale))c \(NutritionInput.format(item.baseFat, locale: locale))f"
        )
        .font(.caption)
        .foregroundStyle(.secondary)
      }
    }
    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
      // Built-in catalog items are read-only. These two
      // actions belong only to the user's personal items.
      if item.isCustom {
        Button(role: .destructive) {
          onDelete()
        } label: {
          Label("Delete", systemImage: "trash")
        }
        Button {
          onEdit()
        } label: {
          Label("Edit", systemImage: "pencil")
        }
        .tint(.blue)
      }
    }
  }
}

#Preview {
  let restaurant = Restaurant(name: "Sample Restaurant")
  restaurant.menuItems = [
    MenuItem(
      name: "Sample Entrée", baseCalories: 400, baseProtein: 20, baseCarbs: 40, baseFat: 15,
      category: .entree),
    MenuItem(
      name: "Sample Side", baseCalories: 200, baseProtein: 3, baseCarbs: 25, baseFat: 9,
      category: .side),
  ]
  return NavigationStack {
    RestaurantDetailView(restaurant: restaurant)
  }
  .modelContainer(
    for: [Restaurant.self, MenuItem.self, FoodItem.self, DiaryEntry.self], inMemory: true)
}
