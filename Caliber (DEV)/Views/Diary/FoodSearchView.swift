import SwiftData
import SwiftUI

private enum FoodSearchScope: String, CaseIterable, Identifiable {
  case all = "All Foods"
  case recent = "Recent"
  case frequent = "Frequent"
  case favorites = "Favorites"
  var id: String { rawValue }
}

/// Search and repeat foods offline. Every result still opens a portion review.
struct FoodSearchView: View {
  @Environment(\.locale) private var locale
  @Environment(\.calendar) private var calendar
  @Environment(\.modelContext) private var modelContext
  @EnvironmentObject private var favorites: FoodLibraryPreferences
  @Query(filter: #Predicate<FoodItem> { $0.isSavedToLibrary }, sort: \FoodItem.name) private
    var savedFoods: [FoodItem]
  @Query(sort: \DiaryEntry.date, order: .reverse) private var entries: [DiaryEntry]
  @Query(sort: \SavedMeal.name) private var savedMeals: [SavedMeal]
  @Query(sort: \Restaurant.name) private var restaurants: [Restaurant]
  let mealType: MealType
  let date: Date
  init(mealType: MealType = .snack, date: Date = .now) {
    self.mealType = mealType
    self.date = date
  }
  @State private var searchService: BundledFoodSearchService?
  @State private var searchText = ""
  @State private var scope = FoodSearchScope.all
  @State private var catalogFoods: [FoodCatalogEntry] = []
  @State private var searchError: String?
  @State private var catalogError: String?
  @State private var isPresentingManualEntry = false
  @State private var favoriteError: String?
  /// Each food in a typed list ("2 eggs, a banana") with its best match.
  @State private var listMatches: [ListMatch] = []
  private var query: String { searchText.trimmingCharacters(in: .whitespacesAndNewlines) }
  private var phrases: [FoodPhrase] { SmartFoodQuery.phrases(in: query) }
  private var isList: Bool { SmartFoodQuery.isList(phrases) }
  /// A list searches item by item below; the sections search the whole text, allowing one typo
  /// when the exact words find nothing in the person's own foods and menus.
  private func matches(_ text: String) -> Bool {
    FoodSearchText.matches(text, query: query)
      || (!hasExactLocalMatch && FoodSearchText.fuzzyMatches(text, query: query))
  }
  private var hasExactLocalMatch: Bool {
    query.isEmpty
      || savedFoods.contains { FoodSearchText.matches($0.name, query: query) }
      || restaurants.flatMap(\.menuItems).contains {
        FoodSearchText.matches($0.name, query: query)
      }
  }
  private var usage: [ReusableFood] {
    FoodReuseIndex.build(
      entries: entries, savedFoods: savedFoods,
      through: DiaryDay.lastInstant(of: .now, calendar: calendar) ?? .now
    )
    .filter { matches($0.food.name + " " + $0.food.servingDescription) }
  }
  private var catalogFavorites: [FoodCatalogEntry] {
    favorites.favoriteKeys.sorted().compactMap { key -> FoodCatalogEntry? in
      guard FoodCatalogSourceType.contains(key: key),
        let food = try? searchService?.catalogEntry(id: key),
        matches(food.name)
      else { return nil }
      return food
    }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
  }
  private var matchingSavedFoods: [FoodItem] {
    savedFoods.filter { matches($0.name + " " + $0.servingDescription) }
  }
  private var matchingMeals: [SavedMeal] {
    savedMeals.filter { matches($0.name) || $0.items.contains { matches($0.foodItem?.name ?? "") } }
  }
  private var matchingMenuItems: [MenuItem] {
    restaurants.flatMap(\.menuItems).filter {
      matches("\($0.restaurant?.name ?? "") \($0.name) \($0.category.displayName)")
    }
    .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
  }
  private var matchingBuilders: [BuildableItemTemplate] {
    restaurants.flatMap(\.buildableTemplates).filter {
      matches(
        ([$0.restaurant?.name ?? "", $0.name]
          + $0.categories.flatMap { [$0.name] + $0.options.map(\.name) }).joined(separator: " "))
    }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
  }

  var body: some View {
    // Build the history index once per render; changing a search does not store another copy.
    let foods = usage
    let recent = FoodReuseIndex.recent(foods, limit: scope == .all ? 5 : 30)
    let frequent = scope == .frequent ? FoodReuseIndex.frequent(foods, limit: 30) : []
    let personalFavorites = foods.filter { $0.food.isSavedToLibrary && favorites.isFavorite($0.id) }
      .sorted {
        $0.food.name == $1.food.name
          ? $0.id < $1.id : $0.food.name.localizedStandardCompare($1.food.name) == .orderedAscending
      }
    let catalogFavorites = self.catalogFavorites
    let hasFavorites = !personalFavorites.isEmpty || !catalogFavorites.isEmpty
    let hasResults: Bool =
      switch scope {
      case .favorites: hasFavorites
      case .recent: !recent.isEmpty
      case .frequent: !frequent.isEmpty
      case .all:
        hasFavorites || !recent.isEmpty || !catalogFoods.isEmpty || !matchingSavedFoods.isEmpty
          || (isList && !listMatches.isEmpty)
          || !matchingMeals.isEmpty || !matchingMenuItems.isEmpty || !matchingBuilders.isEmpty
      }
    return List {
      Group {
        Section {
          if searchService == nil { ProgressView("Opening food database…") }
          Picker("Show", selection: $scope) {
            ForEach(FoodSearchScope.allCases) { Text($0.rawValue).tag($0) }
          }.accessibilityIdentifier("foodSearchScope")
          if scope == .all {
            NavigationLink {
              BarcodeFoodLookupView(mealType: mealType, date: date)
            } label: {
              Label("Scan a Barcode", systemImage: "barcode.viewfinder").frame(minHeight: 48)
            }.accessibilityIdentifier("openBarcode")
            NavigationLink {
              LabelScannerView(mealType: mealType, date: date)
            } label: {
              Label("Scan a Nutrition Label", systemImage: "doc.text.viewfinder")
                .frame(minHeight: 48)
            }.accessibilityIdentifier("openLabelScan")
            NavigationLink {
              PhotoEstimateView(mealType: mealType, date: date)
            } label: {
              Label("Estimate from a Photo", systemImage: "camera.viewfinder")
                .frame(minHeight: 48)
            }.accessibilityIdentifier("openPhotoEstimate")
            Button {
              isPresentingManualEntry = true
            } label: {
              Label("Enter Food Manually", systemImage: "square.and.pencil").frame(minHeight: 48)
            }.accessibilityIdentifier("foodSearchManual")
            NavigationLink {
              RestaurantListView(mealType: mealType, date: date)
            } label: {
              Label("Browse Restaurants", systemImage: "building.2").frame(minHeight: 48)
            }
          }
        } footer: {
          Text(
            "Search USDA foods, saved foods and meals, or restaurant menus offline. Recent and frequent foods use your logged history. Check the preparation and portion before adding."
          )
        }
        if isList && !listMatches.isEmpty {
          Section {
            ForEach(listMatches) { listRow($0) }
          } header: {
            Text("Your list")
          } footer: {
            Text(
              "Each food opens its own review. Amounts you typed are used only with a listed serving or a weight."
            )
          }
        }
        if let searchError { Section { Text(searchError) } }
        if let catalogError {
          Section {
            Text(catalogError)
            Button("Retry Restaurant Loading") { Task { await loadCatalog() } }
          }
        }
        if (scope == .all || scope == .favorites) && hasFavorites {
          Section("Favorites") {
            ForEach(catalogFavorites) { catalogLink($0, favorite: true) }
            ForEach(personalFavorites) { reuseLink($0, prefix: "favorite") }
          }
        }
        if (scope == .all || scope == .recent) && !recent.isEmpty {
          Section("Recent Foods") { ForEach(recent) { reuseLink($0, prefix: "recent") } }
        }
        if scope == .frequent && !frequent.isEmpty {
          Section("Frequently Logged") { ForEach(frequent) { reuseLink($0, prefix: "frequent") } }
        }
        if scope == .all {
          if !matchingSavedFoods.isEmpty {
            Section("My Foods") {
              ForEach(matchingSavedFoods) { food in
                NavigationLink {
                  SavedFoodDetailView(food: food, mealType: mealType, date: date)
                } label: {
                  VStack(alignment: .leading, spacing: 3) {
                    Text(food.name)
                    Text(food.servingDescription).font(.footnote).foregroundStyle(.secondary)
                  }.frame(minHeight: 48)
                }
              }
            }
          }
          if !matchingMeals.isEmpty {
            Section("My Meals") {
              ForEach(matchingMeals) { meal in
                NavigationLink {
                  SavedMealDetailView(meal: meal, mealType: mealType, date: date)
                } label: {
                  VStack(alignment: .leading) {
                    Text(meal.name)
                    Text("\(meal.items.count) foods").font(.footnote)
                  }.frame(minHeight: 48)
                }
              }
            }
          }
          if !catalogFoods.isEmpty {
            Section("USDA Foods") { ForEach(catalogFoods) { catalogLink($0) } }
          }
          if !matchingBuilders.isEmpty {
            Section("Build a Restaurant Meal") {
              ForEach(matchingBuilders) { template in
                NavigationLink {
                  BuildYourOwnView(template: template, mealType: mealType, date: date)
                } label: {
                  VStack(alignment: .leading) {
                    Text(template.name)
                    Text(template.restaurant?.name ?? "Restaurant").font(.footnote)
                  }.frame(minHeight: 48)
                }
              }
            }
          }
          if !matchingMenuItems.isEmpty {
            Section("Restaurant Menu Items") {
              ForEach(matchingMenuItems) { item in
                NavigationLink {
                  MenuItemDetailView(menuItem: item, mealType: mealType, date: date)
                } label: {
                  VStack(alignment: .leading, spacing: 3) {
                    Text(item.name)
                    Text("\(item.restaurant?.name ?? "Restaurant") · \(item.category.displayName)")
                      .font(.footnote)
                  }.frame(minHeight: 48)
                }
              }
            }
          }
        }
        if !hasResults && (scope != .all || searchService != nil) {
          ContentUnavailableView(
            scope == .all
              ? "No Foods Found"
              : scope == .favorites ? "No Favorites Yet" : "No \(scope.rawValue) Foods Yet",
            systemImage: "magnifyingglass",
            description: Text(
              scope == .favorites
                ? "Favorite a USDA food or a personal food to keep it here."
                : "Try another search or log a food to build your history."))
        }
      }
      .listRowBackground(CaliberRowBackground())
    }
    .caliberScreen()
    .navigationTitle("Search Foods")
    .accessibilityIdentifier("foodSearchScreen")
    .searchable(
      text: $searchText, placement: .navigationBarDrawer(displayMode: .always),
      prompt: "Search, or list foods: 2 eggs, a banana"
    )
    .task(id: query) {
      do {
        let service = await BundledFoodSearchService.prepared()
        try Task.checkCancellation()
        searchService = service
        catalogFoods = try service.catalogSearch(query: query, limit: 50)
        if catalogFoods.isEmpty && !isList {
          catalogFoods = try Self.fuzzyCatalogSearch(query, service: service)
        }
        listMatches = isList ? try matchList(phrases, service: service) : []
        searchError = nil
      } catch is CancellationError {} catch {
        catalogFoods = []
        searchError = "The offline food catalog could not be opened. You can enter a food manually."
      }
    }
    .task { await loadCatalog() }
    .sheet(isPresented: $isPresentingManualEntry) {
      AddFoodView(mealType: mealType, date: date).presentationDragIndicator(.visible)
    }
    .alert(
      "Couldn't Update Favorite",
      isPresented: Binding(get: { favoriteError != nil }, set: { if !$0 { favoriteError = nil } })
    ) {
      Button("OK", role: .cancel) { favoriteError = nil }
    } message: {
      Text(favoriteError ?? "Please try again.")
    }
  }
  struct ListMatch: Identifiable {
    let phrase: FoodPhrase
    let saved: FoodItem?
    let catalog: FoodCatalogEntry?
    var id: String { phrase.id }
  }

  /// The person's own saved foods first, then the USDA catalog, with one typo allowed.
  private func matchList(_ phrases: [FoodPhrase], service: BundledFoodSearchService) throws
    -> [ListMatch]
  {
    try phrases.prefix(8).map { phrase in
      let saved =
        savedFoods.first { FoodSearchText.matches($0.name, query: phrase.terms) }
        ?? savedFoods.first { FoodSearchText.fuzzyMatches($0.name, query: phrase.terms) }
      var catalog = try service.catalogSearch(query: phrase.terms, limit: 1).first
      if catalog == nil {
        catalog = try Self.fuzzyCatalogSearch(phrase.terms, service: service).first
      }
      return ListMatch(phrase: phrase, saved: saved, catalog: saved == nil ? catalog : nil)
    }
  }

  /// Searches by the first three letters of each word, then keeps names within one typo.
  private static func fuzzyCatalogSearch(_ query: String, service: BundledFoodSearchService)
    throws -> [FoodCatalogEntry]
  {
    let words = FoodSearchText.normalized(query).split(separator: " ")
    guard words.contains(where: { $0.count >= 4 }) else { return [] }
    let stems = words.map { String($0.prefix(3)) }.joined(separator: " ")
    return try service.catalogSearch(query: stems, limit: 200)
      .filter { FoodSearchText.fuzzyMatches($0.name, query: query) }
      .prefix(50).map { $0 }
  }

  @ViewBuilder private func listRow(_ match: ListMatch) -> some View {
    let amount = match.phrase.quantity.map {
      "\(NutritionInput.format($0, locale: locale))\(match.phrase.unit.map { " \($0)" } ?? "") · "
    }
    if let saved = match.saved {
      NavigationLink {
        SavedFoodDetailView(
          food: saved, initialQuantity: match.phrase.quantity ?? 1, mealType: mealType, date: date)
      } label: {
        listLabel(match.phrase.text, detail: "\(amount ?? "")\(saved.name) · My Foods")
      }
      .accessibilityIdentifier("listMatch-\(match.phrase.terms)")
    } else if let food = match.catalog {
      NavigationLink {
        FoodNutritionReviewView(
          reference: .usda(food), meal: mealType, date: date,
          portion: SmartFoodQuery.portion(
            for: match.phrase, servings: food.servings.map { ($0.id, $0.label) }))
      } label: {
        listLabel(match.phrase.text, detail: "\(amount ?? "")\(food.name) · USDA")
      }
      .accessibilityIdentifier("listMatch-\(match.phrase.terms)")
    } else {
      listLabel(match.phrase.text, detail: "No match. Search for it on its own or enter it.")
    }
  }

  private func listLabel(_ title: String, detail: String) -> some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(title.capitalized(with: locale))
      Text(detail).font(.footnote).foregroundStyle(.secondary)
    }
    .frame(minHeight: 48)
  }

  private func catalogLink(_ food: FoodCatalogEntry, favorite: Bool = false) -> some View {
    NavigationLink {
      FoodNutritionReviewView(reference: .usda(food), meal: mealType, date: date)
    } label: {
      VStack(alignment: .leading, spacing: 3) {
        Text(food.name)
        Text(
          "100 g · \(NutritionInput.format(food.nutritionPer100g.calories, locale: locale)) cal · \(food.sourceType.shortLabel)"
        ).font(.caption).foregroundStyle(.secondary)
      }.frame(minHeight: 48)
    }.accessibilityIdentifier(favorite ? "favorite-\(food.id)" : "catalogFood-\(food.fdcID)")
  }
  private func reuseLink(_ usage: ReusableFood, prefix: String) -> some View {
    NavigationLink {
      SavedFoodDetailView(
        food: usage.food, initialQuantity: usage.quantity, mealType: mealType, date: date)
    } label: {
      VStack(alignment: .leading, spacing: 3) {
        Text(usage.food.name)
        Text(
          "\(NutritionInput.format(usage.quantity, locale: locale)) × \(usage.food.servingDescription) · \(NutritionInput.format(usage.food.calories * usage.quantity, locale: locale)) cal"
        ).font(.footnote).foregroundStyle(.secondary)
        if prefix == "frequent" {
          Text("Logged \(usage.logCount) \(usage.logCount == 1 ? "time" : "times")").font(.caption)
        }
      }.frame(minHeight: 48)
    }.accessibilityIdentifier("\(prefix)-\(usage.id)")
      .swipeActions(edge: .trailing, allowsFullSwipe: false) {
        Button {
          do {
            try FoodFavoriteEditor.setFavorite(
              !favorites.isFavorite(usage.id), food: usage.food, preferences: favorites,
              in: modelContext)
          } catch { favoriteError = error.localizedDescription }
        } label: {
          Label(
            favorites.isFavorite(usage.id) ? "Unfavorite" : "Favorite",
            systemImage: favorites.isFavorite(usage.id) ? "star.slash" : "star")
        }.tint(.blue)
      }
  }
  private func loadCatalog() async {
    do {
      try await RestaurantCatalogSeeder.seedIfNeeded(in: modelContext)
      catalogError = nil
    } catch is CancellationError {} catch {
      catalogError = "Restaurant samples could not be opened. You can still search your foods."
    }
  }
}

#Preview {
  NavigationStack { FoodSearchView() }
    .modelContainer(
      for: [FoodItem.self, DiaryEntry.self, SavedMeal.self, Restaurant.self], inMemory: true
    )
    .environmentObject(
      FoodLibraryPreferences(defaults: UserDefaults(suiteName: "Caliber.Food.Previews")!))
}
