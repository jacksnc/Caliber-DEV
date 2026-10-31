import HeliosDesign
import SwiftData
import SwiftUI

private enum FoodSearchScope: String, CaseIterable, Identifiable {
  case all = "All Foods"
  case recent = "Recent"
  case frequent = "Frequent"
  case favorites = "Favorites"
  var id: String { rawValue }
}

/// Unified offline food-entry workspace. Every route carries the destination meal and date,
/// and every quick action opens an editable portion and macro review before logging.
struct FoodSearchView: View {
  @Environment(\.dynamicTypeSize) private var typeSize
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
    _selectedMealType = State(initialValue: mealType)
  }

  @State private var selectedMealType: MealType
  @State private var searchService: BundledFoodSearchService?
  @State private var searchText = ""
  @State private var scope = FoodSearchScope.all
  @State private var catalogFoods: [FoodCatalogEntry] = []
  @State private var searchError: String?
  @State private var catalogError: String?
  @State private var manualEntryRequest: FoodEntryPass2ManualRequest?
  @State private var activeRoute: FoodEntryPass2Route?
  @State private var quickReviewTarget: FoodEntryPass2QuickReviewTarget?
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

  private func macroPreview(protein: Double, carbs: Double, fat: Double) -> String {
    "P \(NutritionInput.format(protein, locale: locale)) g · C \(NutritionInput.format(carbs, locale: locale)) g · F \(NutritionInput.format(fat, locale: locale)) g"
  }

  var body: some View {
    // Build the history index once per render; changing a search does not store another copy.
    let foods = usage
    let recent = FoodReuseIndex.recent(foods, limit: scope == .all ? 8 : 30)
    let frequent = scope == .frequent ? FoodReuseIndex.frequent(foods, limit: 30) : []
    let personalFavorites = foods.filter { $0.food.isSavedToLibrary && favorites.isFavorite($0.id) }
      .sorted {
        $0.food.name == $1.food.name
          ? $0.id < $1.id : $0.food.name.localizedStandardCompare($1.food.name) == .orderedAscending
      }
    let currentCatalogFavorites = self.catalogFavorites
    let hasFavorites = !personalFavorites.isEmpty || !currentCatalogFavorites.isEmpty
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
        hubSection
        scopeSection
        listSection
        errorSections
        recentSection(recent)
        frequentSection(frequent)
        favoritesSection(
          catalogFavorites: currentCatalogFavorites,
          personalFavorites: personalFavorites
        )
        allScopeSections
        emptyOrCreateSection(hasResults: hasResults)
      }
      .listRowBackground(FoodEntryV2RowBackground())
    }
    .caliberScreen()
    .navigationTitle("Search Foods")
    .toolbar(.visible, for: .navigationBar)
    .accessibilityIdentifier("foodSearchScreen")
    .searchable(
      text: $searchText, placement: .navigationBarDrawer(displayMode: .always),
      prompt: "Search"
    )
    .navigationDestination(item: $activeRoute) { route in
      destinationView(for: route)
    }
    .onChange(of: mealType) { _, next in
      selectedMealType = next
    }
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
    .sheet(item: $manualEntryRequest) { request in
      AddFoodView(mealType: selectedMealType, date: date, prefill: request.prefill)
        .presentationDragIndicator(.visible)
    }
    .sheet(item: $quickReviewTarget) { target in
      FoodEntryPass2QuickReviewSheet(target: target, mealType: selectedMealType, date: date)
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

  private var hubSection: some View {
    Section {
      FoodEntryPass2HubCard(
        mealType: selectedMealType,
        date: date,
        savedFoodsCount: savedFoods.count,
        savedMealsCount: savedMeals.count,
        onSelectMeal: { selectedMealType = $0 },
        onSelectRoute: { activeRoute = $0 },
        onManualEntry: {
          openManualEntry(prefillName: query.isEmpty || isList ? nil : query)
        }
      )
      .foodEntryV2CardRow()
    }
  }

  private var scopeSection: some View {
    Section {
      if searchService == nil {
        ProgressView("Opening food database…")
      }
      Picker("Show", selection: $scope) {
        ForEach(FoodSearchScope.allCases) { option in
          Text(option.rawValue).tag(option)
        }
      }
      .frame(minHeight: 48)
      .accessibilityIdentifier("foodSearchScope")
    } footer: {
      Text(
        "Search saved foods, meals, menus, or the offline catalog. Tap + to review right away."
      )
    }
  }

  @ViewBuilder
  private var listSection: some View {
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
  }

  @ViewBuilder
  private var errorSections: some View {
    if let searchError {
      Section {
        Text(searchError)
      }
    }
    if let catalogError {
      Section {
        Text(catalogError)
        Button("Retry Restaurant Loading") {
          Task { await loadCatalog() }
        }
        .frame(minHeight: 48)
      }
    }
  }

  @ViewBuilder
  private func recentSection(_ recent: [ReusableFood]) -> some View {
    if (scope == .all || scope == .recent) && !recent.isEmpty {
      Section {
        ForEach(recent) { reuseRow($0, prefix: "recent") }
      } header: {
        Text("Recent Foods")
      }
    }
  }

  @ViewBuilder
  private func frequentSection(_ frequent: [ReusableFood]) -> some View {
    if scope == .frequent && !frequent.isEmpty {
      Section {
        ForEach(frequent) { reuseRow($0, prefix: "frequent") }
      } header: {
        Text("Frequently Logged")
      }
    }
  }

  @ViewBuilder
  private func favoritesSection(
    catalogFavorites: [FoodCatalogEntry],
    personalFavorites: [ReusableFood]
  ) -> some View {
    if (scope == .all || scope == .favorites)
      && (!catalogFavorites.isEmpty || !personalFavorites.isEmpty)
    {
      Section {
        ForEach(catalogFavorites) { catalogRow($0, favorite: true) }
        ForEach(personalFavorites) { reuseRow($0, prefix: "favorite") }
      } header: {
        Text("Favorites")
      }
    }
  }

  @ViewBuilder
  private var allScopeSections: some View {
    if scope == .all {
      if !matchingSavedFoods.isEmpty {
        Section {
          ForEach(matchingSavedFoods) { savedFoodRow($0) }
        } header: {
          Text("My Foods")
        }
      }
      if !matchingMeals.isEmpty {
        Section {
          ForEach(matchingMeals) { savedMealRow($0) }
        } header: {
          Text("My Meals")
        }
      }
      if !catalogFoods.isEmpty {
        Section {
          ForEach(catalogFoods) { catalogRow($0) }
        } header: {
          Text("USDA Foods")
        }
      }
      if !matchingBuilders.isEmpty {
        Section {
          ForEach(matchingBuilders) { template in
            NavigationLink {
              BuildYourOwnView(template: template, mealType: selectedMealType, date: date)
            } label: {
              FoodEntryV2FoodRowLabel(
                title: template.name,
                detail: template.restaurant?.name ?? "Restaurant"
              )
            }
          }
        } header: {
          Text("Build a Restaurant Meal")
        }
      }
      if !matchingMenuItems.isEmpty {
        Section {
          ForEach(matchingMenuItems) { item in
            NavigationLink {
              MenuItemDetailView(menuItem: item, mealType: selectedMealType, date: date)
            } label: {
              FoodEntryV2FoodRowLabel(
                title: item.name,
                detail:
                  "\(item.restaurant?.name ?? "Restaurant") · \(item.category.displayName) · \(macroPreview(protein: item.baseProtein, carbs: item.baseCarbs, fat: item.baseFat))",
                caloriesText: "\(NutritionInput.format(item.baseCalories, locale: locale)) cal"
              )
            }
          }
        } header: {
          Text("Restaurant Menu Items")
        }
      }
    }
  }

  @ViewBuilder
  private func emptyOrCreateSection(hasResults: Bool) -> some View {
    if !hasResults && (scope != .all || searchService != nil) {
      Section {
        FoodEntryPass2EmptyStateCard(
          title: emptyStateTitle,
          symbol: "magnifyingglass",
          message: emptyStateMessage,
          query: isList ? "" : query,
          showsSearchAllAction: scope != .all,
          onSearchAll: { scope = .all },
          onCreateManualFood: {
            openManualEntry(prefillName: isList ? nil : query)
          }
        )
        .foodEntryV2CardRow()
      }
    } else if !query.isEmpty && !isList {
      Section {
        Button {
          openManualEntry(prefillName: query)
        } label: {
          Label("Create Custom Food", systemImage: "plus.circle")
            .frame(minHeight: 48)
        }
        .accessibilityIdentifier("foodSearchCreateFromQuery")
      }
    }
  }

  private var emptyStateTitle: String {
    if !query.isEmpty {
      return scope == .all ? "No Foods Found" : "No Matching \(scope.rawValue) Foods"
    }
    return switch scope {
    case .all: "No Foods Found"
    case .favorites: "No Favorites Yet"
    case .recent: "No Recent Foods Yet"
    case .frequent: "No Frequent Foods Yet"
    }
  }

  private var emptyStateMessage: String {
    if !query.isEmpty && scope != .all {
      return
        "Your search stays filled in—check All Foods or create a personal food for \(selectedMealType.displayName)."
    }
    if scope == .favorites {
      return "Star an offline catalog food or a personal food to keep it ready here."
    }
    return "Try another search or enter the food's label values manually."
  }

  @ViewBuilder
  private func destinationView(for route: FoodEntryPass2Route) -> some View {
    switch route {
    case .barcode:
      BarcodeFoodLookupView(mealType: selectedMealType, date: date)
    case .labelScan:
      LabelScannerView(mealType: selectedMealType, date: date)
    case .photoEstimate:
      PhotoEstimateView(mealType: selectedMealType, date: date)
    case .myFoods:
      MyFoodsView(mealType: selectedMealType, date: date)
    case .myMeals:
      MyMealsView(mealType: selectedMealType, date: date)
    case .restaurants:
      RestaurantListView(mealType: selectedMealType, date: date)
    }
  }

  private func openManualEntry(prefillName: String?) {
    let trimmed = prefillName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let prefill =
      trimmed.isEmpty
      ? nil
      : FoodEntryPrefill(
        name: trimmed,
        servingDescription: "",
        calories: "",
        protein: "",
        carbs: "",
        fat: ""
      )
    manualEntryRequest = FoodEntryPass2ManualRequest(prefill: prefill)
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
      var candidates = try service.catalogSearch(query: phrase.terms, limit: 200)
      if candidates.isEmpty {
        candidates = try Self.fuzzyCatalogSearch(phrase.terms, service: service)
      }
      let catalog = CatalogMatch.best(for: phrase.terms, in: candidates)
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

  @ViewBuilder
  private func listRow(_ match: ListMatch) -> some View {
    let amount = match.phrase.quantity.map {
      "\(NutritionInput.format($0, locale: locale))\(match.phrase.unit.map { " \($0)" } ?? "") · "
    }
    if let saved = match.saved {
      let initialQuantity = match.phrase.quantity ?? 1
      foodRowLayout {
        NavigationLink {
          SavedFoodDetailView(
            food: saved, initialQuantity: initialQuantity, mealType: selectedMealType, date: date)
        } label: {
          FoodEntryV2FoodRowLabel(
            title: match.phrase.text.capitalized(with: locale),
            detail: "\(amount ?? "")\(saved.name) · My Foods",
            caloriesText:
              "\(NutritionInput.format(saved.calories * initialQuantity, locale: locale)) cal"
          )
        }
        .accessibilityIdentifier("listMatch-\(match.phrase.terms)")

        FoodEntryPass2QuickReviewButton(
          foodName: saved.name,
          identifier: "foodEntryQuickReview-list-\(match.phrase.terms)"
        ) {
          quickReviewTarget = .savedFood(
            key: "list-\(match.phrase.id)",
            food: saved,
            quantity: initialQuantity
          )
        }
      }
    } else if let food = match.catalog {
      let resolvedPortion = SmartFoodQuery.portion(
        for: match.phrase, servings: food.servings.map { ($0.id, $0.label) })
      foodRowLayout {
        NavigationLink {
          FoodNutritionReviewView(
            reference: .usda(food),
            meal: selectedMealType,
            date: date,
            portion: resolvedPortion
          )
        } label: {
          FoodEntryV2FoodRowLabel(
            title: match.phrase.text.capitalized(with: locale),
            // The requested phrase may use a listed measure. Show nutrition in
            // review, where the existing portion resolver knows its exact mass.
            detail: "\(amount ?? "")\(food.name) · Offline catalog"
          )
        }
        .accessibilityIdentifier("listMatch-\(match.phrase.terms)")

        FoodEntryPass2QuickReviewButton(
          foodName: food.name,
          identifier: "foodEntryQuickReview-list-\(match.phrase.terms)"
        ) {
          quickReviewTarget = .catalogFood(food, portion: resolvedPortion)
        }
      }
    } else {
      Button {
        openManualEntry(prefillName: match.phrase.terms.capitalized(with: locale))
      } label: {
        FoodEntryV2FoodRowLabel(
          title: match.phrase.text.capitalized(with: locale),
          detail: "No match — tap to enter manually for \(selectedMealType.displayName)."
        )
      }
      .accessibilityIdentifier("listCreate-\(match.phrase.terms)")
    }
  }

  // At large sizes the quick action gets its own row, leaving the whole
  // reading width for long food names instead of a very narrow text column.
  private var foodRowLayout: AnyLayout {
    typeSize >= .xxxLarge
      ? AnyLayout(VStackLayout(alignment: .leading, spacing: HeliosTokens.space(2)))
      : AnyLayout(HStackLayout(spacing: HeliosTokens.space(2)))
  }

  private func savedFoodRow(_ food: FoodItem) -> some View {
    foodRowLayout {
      NavigationLink {
        SavedFoodDetailView(food: food, mealType: selectedMealType, date: date)
      } label: {
        FoodEntryV2FoodRowLabel(
          title: food.name,
          detail:
            "\(food.servingDescription) · \(macroPreview(protein: food.proteinGrams, carbs: food.carbGrams, fat: food.fatGrams))",
          caloriesText: "\(NutritionInput.format(food.calories, locale: locale)) cal"
        )
      }

      FoodEntryPass2QuickReviewButton(
        foodName: food.name,
        identifier: "foodEntryQuickReview-savedFood-\(food.id.uuidString)"
      ) {
        quickReviewTarget = .savedFood(
          key: "savedFood-\(food.id.uuidString)",
          food: food,
          quantity: 1
        )
      }
    }
  }

  private func savedMealRow(_ meal: SavedMeal) -> some View {
    foodRowLayout {
      NavigationLink {
        SavedMealDetailView(meal: meal, mealType: selectedMealType, date: date)
      } label: {
        FoodEntryV2FoodRowLabel(
          title: meal.name,
          detail: "\(meal.items.count) \(meal.items.count == 1 ? "food" : "foods")"
        )
      }

      FoodEntryPass2QuickReviewButton(
        foodName: meal.name,
        identifier: "foodEntryQuickReview-savedMeal-\(meal.id.uuidString)"
      ) {
        quickReviewTarget = .savedMeal(meal)
      }
    }
  }

  private func catalogRow(_ food: FoodCatalogEntry, favorite: Bool = false) -> some View {
    let per100g = food.nutritionPer100g
    return foodRowLayout {
      NavigationLink {
        FoodNutritionReviewView(reference: .usda(food), meal: selectedMealType, date: date)
      } label: {
        FoodEntryV2FoodRowLabel(
          title: food.name,
          detail:
            "100 g · \(macroPreview(protein: per100g.proteinGrams, carbs: per100g.carbGrams, fat: per100g.fatGrams)) · \(food.sourceType.shortLabel)",
          caloriesText: "\(NutritionInput.format(per100g.calories, locale: locale)) cal"
        )
      }
      .accessibilityIdentifier(favorite ? "favorite-\(food.id)" : "catalogFood-\(food.fdcID)")

      FoodEntryPass2QuickReviewButton(
        foodName: food.name,
        identifier:
          favorite
          ? "foodEntryQuickReview-favorite-\(food.id)"
          : "foodEntryQuickReview-catalog-\(food.fdcID)"
      ) {
        quickReviewTarget = .catalogFood(food, portion: nil)
      }
    }
  }

  private func reuseRow(_ usage: ReusableFood, prefix: String) -> some View {
    foodRowLayout {
      NavigationLink {
        SavedFoodDetailView(
          food: usage.food,
          initialQuantity: usage.quantity,
          mealType: selectedMealType,
          date: date
        )
      } label: {
        FoodEntryV2FoodRowLabel(
          title: usage.food.name,
          detail:
            "\(NutritionInput.format(usage.quantity, locale: locale)) × \(usage.food.servingDescription) · \(macroPreview(protein: usage.food.proteinGrams * usage.quantity, carbs: usage.food.carbGrams * usage.quantity, fat: usage.food.fatGrams * usage.quantity))",
          caloriesText:
            "\(NutritionInput.format(usage.food.calories * usage.quantity, locale: locale)) cal",
          extraNote:
            prefix == "frequent"
            ? "Logged \(usage.logCount) \(usage.logCount == 1 ? "time" : "times")"
            : nil
        )
      }
      .accessibilityIdentifier("\(prefix)-\(usage.id)")

      FoodEntryPass2QuickReviewButton(
        foodName: usage.food.name,
        identifier: "foodEntryQuickReview-\(prefix)-\(usage.id)"
      ) {
        quickReviewTarget = .savedFood(
          key: "\(prefix)-\(usage.id)",
          food: usage.food,
          quantity: usage.quantity
        )
      }
    }
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
