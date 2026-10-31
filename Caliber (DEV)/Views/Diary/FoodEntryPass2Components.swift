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

enum FoodEntryPass2DateRelation: String, Equatable, Sendable {
  case past
  case today
  case future
}

enum FoodEntryPass2ContextFormatter {
  static func dateRelation(
    for date: Date,
    referenceDate: Date = .now,
    calendar: Calendar = .current
  ) -> FoodEntryPass2DateRelation {
    let targetDay = calendar.startOfDay(for: date)
    let currentDay = calendar.startOfDay(for: referenceDate)
    if targetDay < currentDay {
      return .past
    }
    if targetDay > currentDay {
      return .future
    }
    return .today
  }

  static func badgeTitle(for relation: FoodEntryPass2DateRelation) -> String? {
    switch relation {
    case .past: "Past date"
    case .today: nil
    case .future: "Future date"
    }
  }

  static func badgeTitle(
    for date: Date,
    referenceDate: Date = .now,
    calendar: Calendar = .current
  ) -> String? {
    badgeTitle(for: dateRelation(for: date, referenceDate: referenceDate, calendar: calendar))
  }

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
    return date.formatted(
      Date.FormatStyle(
        date: .abbreviated,
        time: .omitted,
        locale: locale,
        calendar: calendar,
        timeZone: calendar.timeZone
      )
    )
  }

  static func isBackdated(
    _ date: Date,
    referenceDate: Date = .now,
    calendar: Calendar = .current
  ) -> Bool {
    dateRelation(for: date, referenceDate: referenceDate, calendar: calendar) == .past
  }

  static func isFutureDated(
    _ date: Date,
    referenceDate: Date = .now,
    calendar: Calendar = .current
  ) -> Bool {
    dateRelation(for: date, referenceDate: referenceDate, calendar: calendar) == .future
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

/// Opaque readable surface for V2 food cards, tiles, and input containers in Graphite and Frost.
struct FoodEntryV2Surface: View {
  @Environment(\.heliosTheme) private var theme
  var level: GlassLevel = .base
  var cornerRadius: Double = HeliosTokens.radius.card
  var showsShadow: Bool = false

  var body: some View {
    let palette = theme.palette
    let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    shape
      .fill(palette.opaque[level].color)
      .overlay {
        shape.strokeBorder(
          palette.isHighContrast ? palette.border.strong.color : palette.border.hairline.color,
          lineWidth: palette.isHighContrast ? 1.5 : 1
        )
      }
      .shadow(
        color: showsShadow && !theme.reduceTransparency ? palette.shadow.color.color : .clear,
        radius: showsShadow && !theme.reduceTransparency ? palette.shadow.radius : 0,
        x: 0,
        y: showsShadow && !theme.reduceTransparency ? palette.shadow.y : 0
      )
      .accessibilityHidden(true)
  }
}

/// Opaque list row background so Frost and Graphite food forms never rely on translucent blur for contrast.
struct FoodEntryV2RowBackground: View {
  @Environment(\.heliosTheme) private var theme

  var body: some View {
    let palette = theme.palette
    Rectangle()
      .fill(palette.opaque.base.color)
      .overlay {
        if palette.isHighContrast {
          Rectangle().strokeBorder(palette.border.strong.color, lineWidth: 1.5)
        }
      }
      .accessibilityHidden(true)
  }
}

extension View {
  func foodEntryV2CardRow() -> some View {
    padding(HeliosTokens.space(4))
      .background {
        FoodEntryV2Surface(
          level: .base,
          cornerRadius: HeliosTokens.radius.card,
          showsShadow: true
        )
      }
      .listRowInsets(EdgeInsets())
      .listRowBackground(Color.clear)
      .listRowSeparator(.hidden)
  }
}

/// Explicit non-today calendar badge shared between the V2 food hub and review screens.
struct FoodEntryV2DateBadge: View {
  @Environment(\.calendar) private var calendar
  @Environment(\.heliosTheme) private var theme
  let date: Date

  private var dateRelation: FoodEntryPass2DateRelation {
    FoodEntryPass2ContextFormatter.dateRelation(for: date, calendar: calendar)
  }

  var body: some View {
    switch dateRelation {
    case .past:
      StatusBadge(.warning, "Past date")
    case .today:
      EmptyView()
    case .future:
      Label {
        Text("Future date").heliosFont(.footnote)
      } icon: {
        Image(systemName: "calendar.badge.clock")
      }
      .foregroundStyle(theme.palette.accent.base.color)
    }
  }
}

/// Compact Helios V2 workspace header for `FoodSearchView`: destination meal/date context,
/// interactive meal slot pills, capture/manual shortcuts, and personal library navigation.
struct FoodEntryPass2HubCard: View {
  @Environment(\.calendar) private var calendar
  @Environment(\.locale) private var locale
  @Environment(\.heliosTheme) private var theme
  @Environment(\.dynamicTypeSize) private var typeSize

  let mealType: MealType
  let date: Date
  let savedFoodsCount: Int
  let savedMealsCount: Int
  var onSelectMeal: ((MealType) -> Void)? = nil
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

  var body: some View {
    VStack(alignment: .leading, spacing: HeliosTokens.space(3)) {
      contextHeader
      if let onSelectMeal {
        mealDestinationGrid(onSelectMeal: onSelectMeal)
      }
      captureGrid
      libraryGrid
    }
  }

  private var contextHeader: some View {
    ViewThatFits(in: .horizontal) {
      HStack(alignment: .firstTextBaseline, spacing: HeliosTokens.space(2)) {
        contextLabel
        Spacer(minLength: HeliosTokens.space(2))
        FoodEntryV2DateBadge(date: date)
      }
      VStack(alignment: .leading, spacing: HeliosTokens.space(1)) {
        contextLabel
        FoodEntryV2DateBadge(date: date)
      }
    }
  }

  private var contextLabel: some View {
    HStack(spacing: HeliosTokens.space(2)) {
      Image(systemName: FoodEntryPass2ContextFormatter.mealSymbol(for: mealType))
        .foregroundStyle(theme.palette.accent.base.color)
        .accessibilityHidden(true)
      Text("Logging to \(contextText)")
        .heliosFont(.bodyStrong)
        .foregroundStyle(theme.palette.text.primary.color)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("foodEntryContextSummary")
    }
  }

  private func mealDestinationGrid(onSelectMeal: @escaping (MealType) -> Void) -> some View {
    let columnCount: Int =
      if typeSize >= .xxxLarge {
        1
      } else if typeSize >= .xLarge {
        2
      } else {
        4
      }
    let spacing = columnCount == 4 ? HeliosTokens.space(1) : HeliosTokens.space(2)
    let columns = Array(
      repeating: GridItem(.flexible(), spacing: spacing, alignment: .top),
      count: columnCount
    )
    let palette = theme.palette
    return LazyVGrid(columns: columns, spacing: spacing) {
      ForEach(MealType.allCases) { meal in
        let isSelected = meal == mealType
        let shape = RoundedRectangle(cornerRadius: HeliosTokens.radius.chip, style: .continuous)
        Button {
          onSelectMeal(meal)
        } label: {
          VStack(spacing: 3) {
            Text(meal.displayName)
              .heliosFont(.footnote)
              .fontWeight(isSelected ? .semibold : .regular)
              .foregroundStyle(
                isSelected ? palette.accent.base.color : palette.text.primary.color
              )
              .multilineTextAlignment(.center)
              .fixedSize(horizontal: false, vertical: true)
            Capsule()
              .fill(isSelected ? palette.accent.base.color : Color.clear)
              .frame(width: 18, height: 3)
              .accessibilityHidden(true)
          }
          .padding(.horizontal, columnCount == 4 ? HeliosTokens.space(1) : HeliosTokens.space(3))
          .padding(.vertical, HeliosTokens.space(1))
          .frame(maxWidth: .infinity, minHeight: 48)
          .background {
            shape.fill(isSelected ? palette.accent.tint.color : palette.opaque.raised.color)
          }
          .overlay {
            shape.strokeBorder(
              isSelected
                ? palette.accent.base.color
                : (palette.isHighContrast
                  ? palette.border.strong.color : palette.border.hairline.color),
              lineWidth: isSelected || palette.isHighContrast ? 1.5 : 1
            )
          }
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("foodEntryMeal-\(meal.rawValue)")
      }
    }
  }

  private var captureGrid: some View {
    let columns = Array(
      repeating: GridItem(.flexible(), spacing: HeliosTokens.space(2), alignment: .top),
      count: typeSize >= .xxxLarge ? 1 : 2
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
    let columnCount = typeSize >= .xxLarge ? 1 : 3
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
      .background { FoodEntryV2Surface(level: .raised, cornerRadius: HeliosTokens.radius.tile) }
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
      VStack(alignment: .leading, spacing: HeliosTokens.space(1)) {
        HStack {
          Image(systemName: symbol)
            .foregroundStyle(theme.palette.accent.base.color)
            .accessibilityHidden(true)
          if let count {
            Spacer(minLength: 2)
            Text(count)
              .heliosFont(.caption)
              .monospacedDigit()
              .foregroundStyle(theme.palette.text.secondary.color)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
        Text(title)
          .heliosFont(.footnote)
          .fontWeight(.semibold)
          .foregroundStyle(theme.palette.text.primary.color)
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding(.horizontal, HeliosTokens.space(3))
      .padding(.vertical, HeliosTokens.space(2))
      .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
      .background { FoodEntryV2Surface(level: .raised, cornerRadius: HeliosTokens.radius.tile) }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier(identifier)
  }
}

/// Sibling `.borderless` quick-review control (`>= 48x48pt`) so row `NavigationLink`s keep their own IDs
/// and taps never trigger both controls at once.
struct FoodEntryPass2QuickReviewButton: View {
  @Environment(\.heliosTheme) private var theme
  let foodName: String
  let identifier: String
  let action: () -> Void

  var body: some View {
    let palette = theme.palette
    Button(action: action) {
      Image(systemName: "plus.circle.fill")
        .font(.title3)
        .foregroundStyle(palette.accent.base.color)
        .padding(HeliosTokens.space(2))
        .background {
          RoundedRectangle(cornerRadius: HeliosTokens.radius.chip, style: .continuous)
            .fill(palette.accent.subtle.color)
            .overlay {
              RoundedRectangle(cornerRadius: HeliosTokens.radius.chip, style: .continuous)
                .strokeBorder(
                  palette.isHighContrast
                    ? palette.border.strong.color : palette.border.hairline.color,
                  lineWidth: palette.isHighContrast ? 1.5 : 1
                )
            }
        }
        .frame(minWidth: 48, minHeight: 48)
        .contentShape(Rectangle())
    }
    .buttonStyle(.borderless)
    .accessibilityLabel("Quick review \(foodName)")
    .accessibilityIdentifier(identifier)
  }
}

/// Reading-edge food row label with consistent tabular calorie alignment and full-width AX stacking.
struct FoodEntryV2FoodRowLabel: View {
  @Environment(\.dynamicTypeSize) private var typeSize
  @Environment(\.heliosTheme) private var theme

  let title: String
  let detail: String
  var caloriesText: String? = nil
  var extraNote: String? = nil

  var body: some View {
    Group {
      if typeSize >= .xxxLarge {
        VStack(alignment: .leading, spacing: HeliosTokens.space(1)) {
          titleView
          if let caloriesText {
            caloriesView(caloriesText)
          }
          detailView
          extraNoteView
        }
      } else {
        HStack(alignment: .firstTextBaseline, spacing: HeliosTokens.space(3)) {
          VStack(alignment: .leading, spacing: 3) {
            titleView
            detailView
            extraNoteView
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          if let caloriesText {
            caloriesView(caloriesText)
              .fixedSize(horizontal: true, vertical: true)
          }
        }
      }
    }
    .padding(.vertical, 2)
    .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
  }

  private var titleView: some View {
    Text(title)
      .heliosFont(.bodyStrong)
      .foregroundStyle(theme.palette.text.primary.color)
      .fixedSize(horizontal: false, vertical: true)
  }

  private var detailView: some View {
    Text(detail)
      .heliosFont(.footnote)
      .foregroundStyle(theme.palette.text.secondary.color)
      .fixedSize(horizontal: false, vertical: true)
  }

  @ViewBuilder
  private var extraNoteView: some View {
    if let extraNote {
      Text(extraNote)
        .heliosFont(.caption)
        .foregroundStyle(theme.palette.accent.base.color)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private func caloriesView(_ text: String) -> some View {
    Text(text)
      .heliosFont(.callout)
      .monospacedDigit()
      .foregroundStyle(theme.palette.text.secondary.color)
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

/// At AX sizes, each macro is its own self-sizing Form row. A single card
/// containing the entire overview is taller than the available review viewport.
struct FoodEntryV2NutritionSection: View {
  @Environment(\.dynamicTypeSize) private var typeSize
  @Environment(\.heliosTheme) private var theme
  let totals: MacroTotals?
  var portionSummary: String? = nil
  let caloriesIdentifier: String
  let footnote: String
  let invalidMessage: String

  var body: some View {
    Section {
      FoodEntryV2NutritionOverviewCard(
        totals: totals, portionSummary: portionSummary,
        caloriesIdentifier: caloriesIdentifier, footnote: footnote,
        invalidMessage: invalidMessage, showsDetails: !typeSize.isAccessibilitySize
      )
      .foodEntryV2CardRow()
      if typeSize.isAccessibilitySize, let totals {
        FoodEntryPass2MacroSummaryRow(totals: totals, asFormRows: true)
        Text(footnote)
          .heliosFont(.caption)
          .foregroundStyle(theme.palette.text.secondary.color)
          .multilineTextAlignment(.center)
          .fixedSize(horizontal: false, vertical: true)
          .frame(maxWidth: .infinity)
          .foodEntryV2CardRow()
      }
    }
  }
}

/// Centered Lookbook V2 nutrition overview card preserving reported calories and balanced macro tiles.
struct FoodEntryV2NutritionOverviewCard: View {
  @Environment(\.heliosTheme) private var theme
  @Environment(\.locale) private var locale

  let totals: MacroTotals?
  var portionSummary: String? = nil
  let caloriesIdentifier: String
  let footnote: String
  let invalidMessage: String
  var showsDetails = true

  var body: some View {
    let palette = theme.palette
    VStack(spacing: HeliosTokens.space(3)) {
      Text("NUTRITION FOR THIS LOG")
        .heliosFont(.metricLabel)
        .multilineTextAlignment(.center)
        .foregroundStyle(palette.text.secondary.color)
        .fixedSize(horizontal: false, vertical: true)

      if let totals {
        VStack(spacing: HeliosTokens.space(1)) {
          Text("\(NutritionInput.format(totals.calories, locale: locale)) calories")
            .heliosFont(.display)
            .multilineTextAlignment(.center)
            .foregroundStyle(palette.text.primary.color)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier(caloriesIdentifier)

          if let portionSummary {
            Text(portionSummary)
              .heliosFont(.footnote)
              .multilineTextAlignment(.center)
              .foregroundStyle(palette.text.secondary.color)
              .fixedSize(horizontal: false, vertical: true)
          }
        }

        if showsDetails {
          FoodEntryPass2MacroSummaryRow(totals: totals)
          Text(footnote)
            .heliosFont(.caption)
            .multilineTextAlignment(.center)
            .foregroundStyle(palette.text.secondary.color)
            .fixedSize(horizontal: false, vertical: true)
        }
      } else {
        Text(invalidMessage)
          .heliosFont(.callout)
          .multilineTextAlignment(.center)
          .foregroundStyle(palette.text.secondary.color)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .frame(maxWidth: .infinity)
  }
}

/// Full-width opaque review action bar at every text size. Primary actions keep
/// their full 48pt target instead of inheriting the system toolbar's smaller bounds.
struct FoodEntryV2ReviewBottomBar: View {
  @Environment(\.heliosTheme) private var theme
  @Environment(\.caliberReviewFooterPresence) private var reportPresence
  @State private var presenceID = UUID()

  let canSave: Bool
  let didSave: Bool
  let addIdentifier: String
  let onSave: () -> Void
  var onDismiss: (() -> Void)? = nil

  var body: some View {
    let palette = theme.palette
    let buttonShape = RoundedRectangle(cornerRadius: HeliosTokens.radius.button, style: .continuous)
    VStack(spacing: HeliosTokens.space(2)) {
      Button(action: onSave) {
        Text("Add to Diary")
          .heliosFont(.bodyStrong)
          .foregroundStyle(
            canSave ? palette.text.onAccent.color : palette.text.secondary.color
          )
          .multilineTextAlignment(.center)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.horizontal, HeliosTokens.space(3))
          .padding(.vertical, HeliosTokens.space(2))
          .frame(maxWidth: .infinity, minHeight: 48)
          .background {
            if canSave {
              buttonShape.fill(palette.accent.base.color)
            } else {
              FoodEntryV2Surface(level: .raised, cornerRadius: HeliosTokens.radius.button)
            }
          }
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .disabled(!canSave)
      .accessibilityIdentifier(addIdentifier)

      if let onDismiss {
        Button(action: onDismiss) {
          Text(didSave ? "Done" : "Cancel")
            .heliosFont(.body)
            .foregroundStyle(palette.text.primary.color)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, HeliosTokens.space(3))
            .padding(.vertical, HeliosTokens.space(2))
            .frame(maxWidth: .infinity, minHeight: 48)
            .background {
              FoodEntryV2Surface(level: .raised, cornerRadius: HeliosTokens.radius.button)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("foodEntryQuickReviewClose")
      }
    }
    .padding(.horizontal, HeliosTokens.space(4))
    .padding(.vertical, HeliosTokens.space(2))
    .frame(maxWidth: CaliberLayout.readableWidth)
    .frame(maxWidth: .infinity)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("foodEntryReviewBar")
    .background {
      Rectangle()
        .fill(palette.opaque.overlay.color)
        .overlay(alignment: .top) {
          Rectangle()
            .fill(
              palette.isHighContrast ? palette.border.strong.color : palette.border.hairline.color
            )
            .frame(height: 1)
        }
        .ignoresSafeArea()
    }
    .onAppear { reportPresence?(presenceID, true) }
    .onDisappear { reportPresence?(presenceID, false) }
  }
}

/// Reusable Helios macro tiles with semantic series accents and text labels.
struct FoodEntryPass2MacroSummaryRow: View {
  @Environment(\.dynamicTypeSize) private var typeSize
  @Environment(\.heliosTheme) private var theme
  @Environment(\.locale) private var locale
  let totals: MacroTotals
  var asFormRows = false

  var body: some View {
    let data = theme.palette.data
    if asFormRows {
      formRows(data)
    } else if typeSize >= .xxxLarge {
      VStack(alignment: .leading, spacing: HeliosTokens.space(2)) { tiles(data) }
    } else {
      ViewThatFits(in: .horizontal) {
        HStack(spacing: HeliosTokens.space(2)) { tiles(data) }
        VStack(alignment: .leading, spacing: HeliosTokens.space(2)) { tiles(data) }
      }
    }
  }

  /// Flattened rows for the AX Form, rather than one oversized list cell.
  @ViewBuilder private func formRows(_ data: DataColors) -> some View {
    tile("Protein", value: totals.protein, color: data.protein.color)
      .accessibilityIdentifier("foodEntrySummary-protein")
      .foodEntryV2CardRow()
    tile("Carbs", value: totals.carbs, color: data.carbs.color)
      .accessibilityIdentifier("foodEntrySummary-carbs")
      .foodEntryV2CardRow()
    tile("Fat", value: totals.fat, color: data.fat.color)
      .accessibilityIdentifier("foodEntrySummary-fat")
      .foodEntryV2CardRow()
  }

  @ViewBuilder
  private func tiles(_ data: DataColors) -> some View {
    tile("Protein", value: totals.protein, color: data.protein.color)
      .accessibilityIdentifier("foodEntrySummary-protein")
    tile("Carbs", value: totals.carbs, color: data.carbs.color)
      .accessibilityIdentifier("foodEntrySummary-carbs")
    tile("Fat", value: totals.fat, color: data.fat.color)
      .accessibilityIdentifier("foodEntrySummary-fat")
  }

  private func tile(_ title: LocalizedStringKey, value: Double, color: Color) -> some View {
    VStack(alignment: .leading, spacing: HeliosTokens.space(1)) {
      HStack(spacing: 5) {
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
        .monospacedDigit()
        .foregroundStyle(theme.palette.text.primary.color)
        .fixedSize(horizontal: false, vertical: true)
      Capsule()
        .fill(color)
        .frame(height: 4)
        .accessibilityHidden(true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(HeliosTokens.space(3))
    .background { FoodEntryV2Surface(level: .raised, cornerRadius: HeliosTokens.radius.tile) }
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
            .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(.heliosSecondary)
        .accessibilityIdentifier("foodSearchEmptyShowAll")
      }

      Button(action: onCreateManualFood) {
        Text(manualButtonTitle)
          .fixedSize(horizontal: false, vertical: true)
          .frame(maxWidth: .infinity, minHeight: 48)
      }
      .buttonStyle(.heliosPrimary)
      .accessibilityIdentifier("foodSearchEmptyCreateFood")
    }
  }
}
