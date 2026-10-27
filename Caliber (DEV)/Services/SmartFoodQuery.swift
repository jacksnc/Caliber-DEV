import Foundation

/// One food named in a typed list, such as "2 slices of toast" (FUEL-12, text).
struct FoodPhrase: Equatable, Identifiable {
  /// The amount typed, if any ("2", "1/2", "a", "half").
  var quantity: Double?
  /// A unit or size word typed after the amount ("g", "cup", "slice", "large").
  var unit: String?
  /// The food words to search for, singular ("egg", "toast").
  var terms: String
  var text: String
  var id: String { text }
}

/// Turns "2 eggs, a slice of toast and a banana" into separate searches with their amounts.
/// It only reads what was typed: a portion comes from a serving the source lists, never from
/// a guess about how much a food weighs (AGENTS.md).
enum SmartFoodQuery {
  static func phrases(in text: String) -> [FoodPhrase] {
    var normalized = text.lowercased()
    for separator in ["+", ";", "\n"] {
      normalized = normalized.replacingOccurrences(of: separator, with: ",")
    }
    // "and", "with" and "plus" separate foods only when an amount follows, so "2 eggs and a
    // banana" is two foods but "mac and cheese" stays one.
    let chunks = normalized.split(separator: ",").flatMap { chunk -> [String] in
      var parts: [[String]] = [[]]
      let words = chunk.split(separator: " ").map(String.init)
      for (index, word) in words.enumerated() {
        let joins = ["and", "&", "with", "plus"].contains(word)
        if joins, index + 1 < words.count, amount(words[index + 1]) != nil,
          !(parts.last?.isEmpty ?? true)
        {
          parts.append([])
        } else {
          parts[parts.count - 1].append(word)
        }
      }
      return parts.map { $0.joined(separator: " ") }
    }
    return chunks.compactMap { part -> FoodPhrase? in
      let original = part.trimmingCharacters(in: .whitespaces)
      var words = original.split(separator: " ").map(String.init)
      guard !words.isEmpty else { return nil }
      var quantity: Double?
      if let first = words.first, let value = amount(first) {
        quantity = value
        words.removeFirst()
        // "1 1/2 cups"
        if let next = words.first, next.contains("/"), let fraction = amount(next), fraction < 1 {
          quantity = value + fraction
          words.removeFirst()
        }
      }
      var unit: String?
      if quantity != nil, let first = words.first, let canonical = units[first] {
        unit = canonical
        words.removeFirst()
      }
      if words.first == "of" { words.removeFirst() }
      let terms = words.map(singular).joined(separator: " ")
      guard !terms.isEmpty else { return nil }
      return FoodPhrase(quantity: quantity, unit: unit, terms: terms, text: original)
    }
  }

  /// A typed list is worth matching item by item when it names several foods or an amount.
  static func isList(_ phrases: [FoodPhrase]) -> Bool {
    phrases.count > 1 || phrases.contains { $0.quantity != nil }
  }

  /// The review screen's portion for a phrase: grams or ounces as typed, or a serving the
  /// source lists whose label holds the typed unit ("slice" → "1 slice"). With no unit, a food
  /// that lists exactly one serving uses it. Otherwise nil, and the person chooses.
  static func portion(
    for phrase: FoodPhrase, servings: [(id: String, label: String)]
  ) -> (choiceID: String, amount: Double)? {
    guard let quantity = phrase.quantity, quantity > 0 else { return nil }
    switch phrase.unit {
    case "g": return ("grams", quantity)
    case "oz": return ("ounces", quantity)
    case let unit?:
      let match = servings.first { serving in
        FoodSearchText.normalized(serving.label).split(separator: " ")
          .contains { singular(String($0)) == unit }
      }
      return match.map { ($0.id, quantity) }
    case nil:
      return servings.count == 1 ? (servings[0].id, quantity) : nil
    }
  }

  static func singular(_ word: String) -> String {
    guard word.count > 3, !word.hasSuffix("ss"), !word.hasSuffix("us") else { return word }
    if word.hasSuffix("ies") { return String(word.dropLast(3)) + "y" }
    if word.hasSuffix("oes") || word.hasSuffix("ches") || word.hasSuffix("shes") {
      return String(word.dropLast(2))
    }
    if word.hasSuffix("s") { return String(word.dropLast()) }
    return word
  }

  private static let numberWords: [String: Double] = [
    "a": 1, "an": 1, "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6,
    "seven": 7, "eight": 8, "nine": 9, "ten": 10, "twelve": 12, "half": 0.5, "½": 0.5,
    "¼": 0.25, "¾": 0.75, "dozen": 12,
  ]

  private static func amount(_ word: String) -> Double? {
    if let value = numberWords[word] { return value }
    if word.contains("/") {
      let parts = word.split(separator: "/")
      guard parts.count == 2, let top = Double(parts[0]), let bottom = Double(parts[1]),
        bottom > 0
      else { return nil }
      return top / bottom
    }
    guard let value = Double(word), value.isFinite, value > 0 else { return nil }
    return value
  }

  private static let units: [String: String] = [
    "g": "g", "gram": "g", "grams": "g", "oz": "oz", "ounce": "oz", "ounces": "oz",
    "cup": "cup", "cups": "cup", "tbsp": "tbsp", "tablespoon": "tbsp", "tablespoons": "tbsp",
    "tsp": "tsp", "teaspoon": "tsp", "teaspoons": "tsp", "slice": "slice", "slices": "slice",
    "piece": "piece", "pieces": "piece", "large": "large", "medium": "medium", "small": "small",
    "scoop": "scoop", "scoops": "scoop", "serving": "serving", "servings": "serving",
  ]
}

extension FoodSearchText {
  /// Like `matches`, but a word of four or more letters also matches with one typo
  /// ("chiken" finds "chicken"). Used when the exact search finds nothing.
  static func fuzzyMatches(_ text: String, query: String) -> Bool {
    let words = normalized(text).split(separator: " ").map(String.init)
    return normalized(query).split(separator: " ").allSatisfy { part in
      let query = String(part)
      return words.contains { word in
        if word.contains(query) { return true }
        guard query.count >= 4 else { return false }
        return editDistance(query, word) <= 1
          || editDistance(query, String(word.prefix(query.count))) <= 1
      }
    }
  }

  static func editDistance(_ lhs: String, _ rhs: String) -> Int {
    let a = Array(lhs)
    let b = Array(rhs)
    if a.isEmpty { return b.count }
    if b.isEmpty { return a.count }
    var previous = Array(0...b.count)
    for i in 1...a.count {
      var current = [i] + Array(repeating: 0, count: b.count)
      for j in 1...b.count {
        current[j] = min(
          previous[j] + 1, current[j - 1] + 1, previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1))
      }
      previous = current
    }
    return previous[b.count]
  }
}

/// Picks the database food a list item or photo item most plausibly means. The catalog search
/// finds every name containing the words ("banana" also finds "Peppers, banana"), so this
/// prefers names that start with the food, then plain forms over processed ones, then shorter
/// names. The person still sees the matched name and can choose another.
enum CatalogMatch {
  static func best(for terms: String, in candidates: [FoodCatalogEntry]) -> FoodCatalogEntry? {
    let query = FoodSearchText.normalized(terms).split(separator: " ").map {
      SmartFoodQuery.singular(String($0))
    }
    guard !query.isEmpty else { return candidates.first }
    return candidates.enumerated().min { lhs, rhs in
      let left = score(lhs.element.name, query: query)
      let right = score(rhs.element.name, query: query)
      return left == right ? lhs.offset < rhs.offset : left < right
    }?.element
  }

  /// Lower is better.
  static func score(_ name: String, query: [String]) -> Int {
    let segments = name.split(separator: ",").map {
      FoodSearchText.normalized(String($0)).split(separator: " ").map {
        SmartFoodQuery.singular(String($0))
      }
    }
    let first = segments.first ?? []
    let words = segments.flatMap { $0 }
    var score = words.count
    // "Rice, white, cooked" is rice; "Rice crackers" only starts with it.
    if first == query {
      score -= 100
    } else if first.starts(with: query) {
      score -= 60
    }
    if words.contains(where: processed.contains) { score += 20 }
    // "Whole" marks a food's default form ("Egg, whole" rather than "Egg, white").
    if words.contains("whole") { score -= 2 }
    return score
  }

  private static let processed: Set<String> = [
    "dried", "dehydrated", "powder", "powdered", "frozen", "canned", "concentrate", "flour",
  ]
}
