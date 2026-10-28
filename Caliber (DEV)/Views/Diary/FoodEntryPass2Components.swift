import HeliosDesign
import SwiftData
import SwiftUI

enum FoodEntryPass2Route: String, Identifiable, Hashable {
  case barcode
  case labelScan
  case photoEstimate
  case myFoods
  case myMeals
  case restaurants

  var id: String { rawValue }
}

enum FoodEntryPass2QuickReviewTarget: Identifiable {
  case savedFood(key: String, food: FoodItem, quantity: Double)
  case catalogFood(FoodCatalogEntry, portion: (choiceID: String, amount: Double)?)
  case savedMeal(SavedMeal)

  var id: String {
    switch self {
    case .savedFood(let key, _, _): "saved-\(key)"
    case .catalogFood(let entry, _): "catalog-\(entry.id)"
    case .savedMeal(let meal): "meal-\(meal.id.uuidString)"
    }
  }
}

struct FoodEntryPass2ManualRequest: Identifiable {
  let id = UUID()
  let prefill: FoodEntryPrefill?
}

enum FoodEntryPass2ContextFormatter {
  static func dateLabel(
    for date: Date,
    referenceDate: Date = .now,
    calendar: Calendar = .current,
    locale: Locale = .current
  ) -> String {
    if calendar.isDate(date, inSameDayAs: referenceDate) {
      return "Today"
    }
    if let yesterday = calendar.date(byAdding: .day, value: -1, to: referenceDate),
      calendar.isDate(date, inSameDayAs: yesterday)
    {
      return "Yesterday"
    }
    if let tomorrow = calendar.date(byAdding: .day, value: 1, to: referenceDate),
      calendar.isDate(date, inSameDayAs: tomorrow)
    {
      return "Tomorrow"
    }
    return date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(locale))
  }

  static func isBackdated(
    _ date: Date,
    referenceDate: Date = .now,
    calendar: Calendar = .current
  ) -> Bool {
    calendar.startOfDay(for: date) < calendar.startOfDay(for: referenceDate)
  }

  static func summary(
    meal: MealType,
    date: Date,
    referenceDate: Date = .now,
    calendar: Calendar = .current,
    locale: Locale = .current
  ) -> String {
    "\(meal.displayName) · \(dateLabel(for: date, referenceDate: referenceDate, calendar: calendar, locale: locale))"
  }

  static func mealSymbol(for meal: MealType) -> String {
    switch meal {
    case .breakfast: "sunrise"
    case .lunch: "sun.max"
    case .dinner: "moon.stars"
    case .snack: "leaf"
    }
  }
}

/// Pure draft and validation rules for compact manual entry.
/// Blank macros stay invalid rather than silently inventing 0 g values.
struct FoodEntryPass2ManualDraft: Equatable {
  enum ValidationError: LocalizedError, Equatable {
    case invalidInput

    var errorDescription: String? {
      "Enter a food name, all four nonnegative nutrition values, and a quantity greater than zero."
    }
  }

  var name: String = ""
  var servingDescription: String = ""
  var quantity: String = "1"
  var calories: String = ""
  var protein: String = ""
  var carbs: String = ""
  var fat: String = ""
  var saveToLibrary: Bool = true

  init(
    name: String = "",
    servingDescription: String = "",
    quantity: String = "1",
    calories: String = "",
    protein: String = "",
    carbs: String = "",
    fat: String = "",
    saveToLibrary: Bool = true
  ) {
    self.name = name
    self.servingDescription = servingDescription
    self.quantity = quantity
    self.calories = calories
    self.protein = protein
    self.carbs = carbs
    self.fat = fat
    self.saveToLibrary = saveToLibrary
  }

  init(prefill: FoodEntryPrefill?, saveToLibrary: Bool = true) {
    self.saveToLibrary = saveToLibrary
    if let prefill {
      self.name = prefill.name
      self.servingDescription = prefill.servingDescription
      self.calories = prefill.calories
      self.protein = prefill.protein
      self.carbs = prefill.carbs
      self.fat = prefill.fat
    }
  }

  var trimmedName: String {
    name.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  var resolvedServingDescription: String {
    let trimmed = servingDescription.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? "1 serving" : trimmed
  }

  var hasAnyMacroText: Bool {
    ![calories, protein, carbs, fat].allSatisfy {
      $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
  }

  func perServingTotals(locale: Locale = .current) -> MacroTotals? {
    guard
      let totals = NutritionInput.totals(
        calories: calories,
        protein: protein,
        carbs: carbs,
        fat: fat,
        locale: locale
      ),
      totals.isValid
    else {
      return nil
    }
    return totals
  }

  func resolvedQuantity(locale: Locale = .current) -> Double? {
    NutritionInput.quantity(quantity, locale: locale)
  }

  func scaledTotals(locale: Locale = .current) -> MacroTotals? {
    guard let totals = perServingTotals(locale: locale),
      let amount = resolvedQuantity(locale: locale)
    else {
      return nil
    }
    let scaled = totals.scaled(by: amount)
    return scaled.isValid ? scaled : nil
  }

  func canSave(locale: Locale = .current) -> Bool {
    !trimmedName.isEmpty && scaledTotals(locale: locale) != nil
  }
}

@MainActor
enum FoodEntryPass2ManualLogger {
  @discardableResult
  static func log(
    draft: FoodEntryPass2ManualDraft,
    mealType: MealType,
    date: Date,
    locale: Locale = .current,
    in context: ModelContext,
    persist: (ModelContext) throws -> Void = { try $0.save() }
  ) throws -> DiaryEntry {
    guard !draft.trimmedName.isEmpty,
      date.timeIntervalSinceReferenceDate.isFinite,
      let totals = draft.perServingTotals(locale: locale),
      let amount = draft.resolvedQuantity(locale: locale),
      totals.scaled(by: amount).isValid
    else {
      throw FoodEntryPass2ManualDraft.ValidationError.invalidInput
    }

    let food = FoodItem(
      name: draft.trimmedName,
      calories: totals.calories,
      proteinGrams: totals.protein,
      carbGrams: totals.carbs,
      fatGrams: totals.fat,
      servingDescription: draft.resolvedServingDescription,
      isSavedToLibrary: draft.saveToLibrary
    )
    let entry = DiaryEntry(
      date: date,
      mealType: mealType,
      foodItem: food,
      quantity: amount
    )
    context.insert(food)
    context.insert(entry)
    do {
      try persist(context)
      return entry
    } catch {
      context.delete(entry)
      context.delete(food)
      throw error
    }
  }
}

/// Compact Helios workspace header for `FoodSearchView`: active meal/date context,
/// capture/manual shortcuts, and direct personal library navigation.
struct FoodEntryPass2HubCard: View {
  @Environment(\.calendar) private var calendar
  @Environment(\.locale) private var locale
  @Environment(\.heliosTheme) private var theme
  @Environment(\.dynamicTypeSize) private var typeSize

  let mealType: MealType
  let date: Date
  let savedFoodsCount: Int
  let savedMealsCount: Int
  let onSelectRoute: (FoodEntryPass2Route) -> Void
  let onManualEntry: () -> Void

  private var contextText: String {
    FoodEntryPass2ContextFormatter.summary(
      meal: mealType,
      date: date,
      calendar: calendar,
      locale: locale
    )
  }

  private var isBackdated: Bool {
    FoodEntryPass2ContextFormatter.isBackdated(date, calendar: calendar)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: HeliosTokens.space(3)) {
      contextHeader
      captureGrid
      libraryGrid
    }
  }

  private var contextHeader: some View {
    ViewThatFits(in: .horizontal) {
      HStack(alignment: .firstTextBaseline, spacing: HeliosTokens.space(2)) {
        contextLabel
        Spacer(minLength: HeliosTokens.space(2))
        if isBackdated {
          StatusBadge(.warning, "Past date")
        }
      }
      VStack(alignment: .leading, spacing: HeliosTokens.space(1)) {
        contextLabel
        if isBackdated {
          StatusBadge(.warning, "Past date")
        }
      }
    }
  }

  private var contextLabel: some View {
    HStack(spacing: HeliosTokens.space(2)) {
      Image(systemName: FoodEntryPass2ContextFormatter.mealSymbol(for: mealType))
        .foregroundStyle(theme.palette.accent.base.color)
        .accessibilityHidden(true)
      Text("Logging to \(contextText)")
        .heliosFont(.callout)
        .foregroundStyle(theme.palette.text.secondary.color)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("foodEntryContextSummary")
    }
  }

  private var captureGrid: some View {
    let columns = Array(
      repeating: GridItem(.flexible(), spacing: HeliosTokens.space(2), alignment: .top),
      count: typeSize.isAccessibilitySize ? 1 : 2
    )
    return LazyVGrid(columns: columns, spacing: HeliosTokens.space(2)) {
      shortcutTile(
        title: "Barcode",
        symbol: "barcode.viewfinder",
        identifier: "openBarcode",
        accessibilityTitle: "Scan a Barcode"
      ) {
        onSelectRoute(.barcode)
      }
      shortcutTile(
        title: "Label",
        symbol: "doc.text.viewfinder",
        identifier: "openLabelScan",
        accessibilityTitle: "Scan a Nutrition Label"
      ) {
        onSelectRoute(.labelScan)
      }
      shortcutTile(
        title: "Photo",
        symbol: "camera.viewfinder",
        identifier: "openPhotoEstimate",
        accessibilityTitle: "Estimate from a Photo"
      ) {
        onSelectRoute(.photoEstimate)
      }
      shortcutTile(
        title: "Manual",
        symbol: "square.and.pencil",
        identifier: "foodSearchManual",
        accessibilityTitle: "Enter Food Manually",
        action: onManualEntry
      )
    }
  }

  private var libraryGrid: some View {
    let columnCount = typeSize >= .xxxLarge ? 1 : 3
    let columns = Array(
      repeating: GridItem(.flexible(), spacing: HeliosTokens.space(2), alignment: .top),
      count: columnCount
    )
    return LazyVGrid(columns: columns, spacing: HeliosTokens.space(2)) {
      libraryTile(
        title: "My Foods",
        count: savedFoodsCount > 0 ? "\(savedFoodsCount)" : nil,
        symbol: "carrot",
        identifier: "foodEntryOpenMyFoods"
      ) {
        onSelectRoute(.myFoods)
      }
      libraryTile(
        title: "Meals",
        count: savedMealsCount > 0 ? "\(savedMealsCount)" : nil,
        symbol: "square.stack.3d.up",
        identifier: "foodEntryOpenMyMeals"
      ) {
        onSelectRoute(.myMeals)
      }
      libraryTile(
        title: "Restaurants",
        count: nil,
        symbol: "building.2",
        identifier: "foodEntryOpenRestaurants"
      ) {
        onSelectRoute(.restaurants)
      }
    }
  }

  private func shortcutTile(
    title: LocalizedStringKey,
    symbol: String,
    identifier: String,
    accessibilityTitle: LocalizedStringKey,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: HeliosTokens.space(2)) {
        Image(systemName: symbol)
          .foregroundStyle(theme.palette.accent.base.color)
          .accessibilityHidden(true)
        Text(title)
          .heliosFont(.bodyStrong)
          .foregroundStyle(theme.palette.text.primary.color)
          .fixedSize(horizontal: false, vertical: true)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(.horizontal, HeliosTokens.space(3))
      .padding(.vertical, HeliosTokens.space(2))
      .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
      .background { GlassBackground(level: .raised, cornerRadius: HeliosTokens.radius.tile) }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(accessibilityTitle)
    .accessibilityIdentifier(identifier)
  }

  private func libraryTile(
    title: LocalizedStringKey,
    count: String?,
    symbol: String,
    identifier: String,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: HeliosTokens.space(1)) {
        Image(systemName: symbol)
          .foregroundStyle(theme.palette.text.secondary.color)
          .accessibilityHidden(true)
        Text(title)
          .heliosFont(.footnote)
          .foregroundStyle(theme.palette.text.primary.color)
          .fixedSize(horizontal: false, vertical: true)
        if let count {
          Spacer(minLength: 2)
          Text(count)
            .heliosFont(.caption)
            .foregroundStyle(theme.palette.text.secondary.color)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      .padding(.horizontal, HeliosTokens.space(2))
      .padding(.vertical, HeliosTokens.space(2))
      .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
      .background { GlassBackground(level: .raised, cornerRadius: HeliosTokens.radius.tile) }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier(identifier)
  }
}

/// Sibling `.borderless` quick-review control so row `NavigationLink`s keep their own IDs
/// and taps never trigger both controls at once.
struct FoodEntryPass2QuickReviewButton: View {
  @Environment(\.heliosTheme) private var theme
  let foodName: String
  let identifier: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: "plus.circle.fill")
        .font(.title3)
        .foregroundStyle(theme.palette.accent.base.color)
        .frame(minWidth: 44, minHeight: 48)
        .contentShape(Rectangle())
    }
    .buttonStyle(.borderless)
    .accessibilityLabel("Quick review \(foodName)")
    .accessibilityIdentifier(identifier)
  }
}

/// Presents the existing editable portion/macro review screen in a dismissible sheet.
struct FoodEntryPass2QuickReviewSheet: View {
  @Environment(\.dismiss) private var dismiss
  let target: FoodEntryPass2QuickReviewTarget
  let mealType: MealType
  let date: Date

  var body: some View {
    NavigationStack {
      switch target {
      case .savedFood(_, let food, let quantity):
        SavedFoodDetailView(
          food: food,
          initialQuantity: quantity,
          mealType: mealType,
          date: date,
          onDismiss: { dismiss() }
        )
      case .catalogFood(let entry, let portion):
        FoodNutritionReviewView(
          reference: .usda(entry),
          meal: mealType,
          date: date,
          portion: portion,
          onDismiss: { dismiss() }
        )
      case .savedMeal(let meal):
        SavedMealDetailView(
          meal: meal,
          mealType: mealType,
          date: date,
          onDismiss: { dismiss() }
        )
      }
    }
    .presentationDetents([.large])
    .presentationDragIndicator(.visible)
  }
}

/// Reusable Helios macro tiles with semantic series dots and text labels.
struct FoodEntryPass2MacroSummaryRow: View {
  @Environment(\.heliosTheme) private var theme
  @Environment(\.locale) private var locale
  let totals: MacroTotals

  var body: some View {
    let data = theme.palette.data
    ViewThatFits(in: .horizontal) {
      HStack(spacing: HeliosTokens.space(2)) { tiles(data) }
      VStack(alignment: .leading, spacing: HeliosTokens.space(2)) { tiles(data) }
    }
  }

  @ViewBuilder
  private func tiles(_ data: DataColors) -> some View {
    tile("Protein", value: totals.protein, color: data.protein.color)
    tile("Carbs", value: totals.carbs, color: data.carbs.color)
    tile("Fat", value: totals.fat, color: data.fat.color)
  }

  private func tile(_ title: LocalizedStringKey, value: Double, color: Color) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack(spacing: 4) {
        Circle()
          .fill(color)
          .frame(width: 7, height: 7)
          .accessibilityHidden(true)
        Text(title)
          .heliosFont(.caption)
          .foregroundStyle(theme.palette.text.secondary.color)
          .fixedSize(horizontal: false, vertical: true)
      }
      Text("\(NutritionInput.format(value, locale: locale)) g")
        .heliosFont(.bodyStrong)
        .foregroundStyle(theme.palette.text.primary.color)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(HeliosTokens.space(2))
    .background { GlassBackground(level: .raised, cornerRadius: HeliosTokens.radius.tile) }
    .accessibilityElement(children: .combine)
  }
}

/// Honest empty / no-results state with direct recovery and manual-create actions.
struct FoodEntryPass2EmptyStateCard: View {
  @Environment(\.heliosTheme) private var theme
  let title: String
  let symbol: String
  let message: String
  let query: String
  let showsSearchAllAction: Bool
  let onSearchAll: () -> Void
  let onCreateManualFood: () -> Void

  private var manualButtonTitle: String {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty || trimmed.count > 36 {
      return "Enter Food Manually"
    }
    return "Enter \"\(trimmed)\" Manually"
  }

  var body: some View {
    VStack(alignment: .leading, spacing: HeliosTokens.space(3)) {
      HStack(spacing: HeliosTokens.space(2)) {
        Image(systemName: symbol)
          .foregroundStyle(theme.palette.accent.base.color)
          .accessibilityHidden(true)
        Text(title)
          .heliosFont(.section)
          .foregroundStyle(theme.palette.text.primary.color)
          .fixedSize(horizontal: false, vertical: true)
      }
      Text(message)
        .heliosFont(.callout)
        .foregroundStyle(theme.palette.text.secondary.color)
        .fixedSize(horizontal: false, vertical: true)

      if showsSearchAllAction {
        Button(action: onSearchAll) {
          Text("Search All Foods")
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.heliosSecondary)
        .accessibilityIdentifier("foodSearchEmptyShowAll")
      }

      Button(action: onCreateManualFood) {
        Text(manualButtonTitle)
          .fixedSize(horizontal: false, vertical: true)
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.heliosPrimary)
      .accessibilityIdentifier("foodSearchEmptyCreateFood")
    }
  }
}
