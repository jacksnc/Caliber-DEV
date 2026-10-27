import HeliosDesign
import SwiftData
import SwiftUI

/// Ranks a menu's own listed values against what is left of today's goals. It never estimates
/// nutrition: an item without listed values is not ranked (AGENTS.md).
enum RestaurantFit {
  enum Verdict: Equatable { case fits, close }

  struct Window: Equatable {
    let minCalories: Double
    let maxCalories: Double
    let minProtein: Double
  }

  struct Match: Identifiable {
    let item: MenuItem
    let verdict: Verdict
    let distance: Double
    var id: PersistentIdentifier { item.persistentModelID }
  }

  /// A meal window around the calories left today (±10%), asking for 40% of the protein
  /// left, rounded down to 5 g. Nil when no calorie goal is set or nothing is left.
  static func window(goal: Double?, proteinGoal: Double?, eaten: MacroTotals) -> Window? {
    guard let goal, goal > 0 else { return nil }
    let left = goal - eaten.calories
    guard left >= 150 else { return nil }
    let proteinLeft = max(0, (proteinGoal ?? 0) - eaten.protein)
    return Window(
      minCalories: (left * 0.9).rounded(), maxCalories: (left * 1.1).rounded(),
      minProtein: (proteinLeft * 0.4 / 5).rounded(.down) * 5)
  }

  /// Items inside the window are "fits"; within a further 10% of calories, or 80% of the
  /// protein, are "close". Closest to the window's centre first, at most `limit`.
  static func matches(in items: [MenuItem], window: Window, limit: Int = 3) -> [Match] {
    let centre = (window.minCalories + window.maxCalories) / 2
    let slack = (window.maxCalories - window.minCalories) / 2
    return items.compactMap { item -> Match? in
      let kcal = item.baseCalories
      guard kcal.isFinite, kcal > 0 else { return nil }
      let calorieOK = kcal >= window.minCalories && kcal <= window.maxCalories
      let proteinOK = item.baseProtein >= window.minProtein
      let nearCalories = abs(kcal - centre) <= slack * 2
      let nearProtein = item.baseProtein >= window.minProtein * 0.8
      let verdict: Verdict
      if calorieOK && proteinOK {
        verdict = .fits
      } else if nearCalories && nearProtein {
        verdict = .close
      } else {
        return nil
      }
      return Match(item: item, verdict: verdict, distance: abs(kcal - centre))
    }
    .sorted {
      if $0.verdict != $1.verdict { return $0.verdict == .fits }
      return $0.distance < $1.distance
    }
    .prefix(limit)
    .map { $0 }
  }
}

/// Look book: restaurant chips and "Fits your day" above the restaurant list.
struct RestaurantFitCard: View {
  let restaurants: [Restaurant]
  let mealType: MealType
  let date: Date
  @Query(sort: \DiaryEntry.date) private var diary: [DiaryEntry]
  @Query private var profiles: [UserProfile]
  @State private var selectedName: String?
  @Environment(\.heliosTheme) private var theme
  @Environment(\.locale) private var locale

  var body: some View {
    let today = diary.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
    let window = RestaurantFit.window(
      goal: profiles.first?.dailyCalorieGoal, proteinGoal: profiles.first?.proteinGoal,
      eaten: MacroCalculator.totals(for: today))
    let selected =
      restaurants.first { $0.name == selectedName } ?? restaurants.first
    if let window, let selected {
      VStack(alignment: .leading, spacing: HeliosTokens.space(3)) {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: HeliosTokens.space(2)) {
            ForEach(restaurants) { restaurant in
              Button {
                selectedName = restaurant.name
              } label: {
                HeliosChip(
                  LocalizedStringKey(restaurant.name), isSelected: restaurant.name == selected.name)
              }
              .buttonStyle(.plain)
            }
          }
        }
        VStack(alignment: .leading, spacing: HeliosTokens.space(3)) {
          VStack(alignment: .leading, spacing: 2) {
            SectionHeader("Fits your day")
            Text(
              "\(number(window.minCalories))–\(number(window.maxCalories)) kcal · protein \(number(window.minProtein)) g or more"
            )
            .heliosFont(.footnote)
            .foregroundStyle(theme.palette.text.secondary.color)
          }
          let matches = RestaurantFit.matches(in: selected.menuItems, window: window)
          if matches.isEmpty {
            Text("Nothing on this menu fits what is left today.")
              .heliosFont(.callout)
              .foregroundStyle(theme.palette.text.secondary.color)
          }
          ForEach(matches) { match in
            NavigationLink {
              MenuItemDetailView(menuItem: match.item, mealType: mealType, date: date)
            } label: {
              row(match)
            }
            .buttonStyle(.plain)
          }
          Text("Ranked from this menu's listed values against what is left of today's goals.")
            .heliosFont(.caption)
            .foregroundStyle(theme.palette.text.secondary.color)
        }
        .glassCard()
      }
      .accessibilityIdentifier("restaurantFitCard")
    }
  }

  private func row(_ match: RestaurantFit.Match) -> some View {
    let item = match.item
    return VStack(alignment: .leading, spacing: 2) {
      HStack(alignment: .firstTextBaseline) {
        Text(item.name).heliosFont(.bodyStrong)
          .foregroundStyle(theme.palette.text.primary.color)
          .frame(maxWidth: .infinity, alignment: .leading)
        switch match.verdict {
        case .fits: StatusBadge(.success, "Fits")
        case .close: StatusBadge(.warning, "Close")
        }
      }
      Text(
        "\(number(item.baseCalories)) kcal · P \(number(item.baseProtein)) · C \(number(item.baseCarbs)) · F \(number(item.baseFat))"
      )
      .heliosFont(.footnote)
      .foregroundStyle(theme.palette.text.secondary.color)
    }
    .padding(HeliosTokens.space(3))
    .frame(minHeight: 48)
    .background { GlassBackground(level: .raised, cornerRadius: HeliosTokens.radius.tile) }
    .contentShape(Rectangle())
  }

  private func number(_ value: Double) -> String {
    NutritionInput.format(value.rounded(), locale: locale)
  }
}
