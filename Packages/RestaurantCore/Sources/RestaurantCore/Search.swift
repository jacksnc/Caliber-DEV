import Foundation

public struct SearchContext: Sendable {
    /// Restaurant or item IDs the user has starred.
    public var favoriteIDs: Set<String>
    /// Restaurant or item IDs, most recent first.
    public var recentIDs: [String]
    /// E.g. the chain nearest the user's current location.
    public var preferredRestaurantID: String?

    public init(favoriteIDs: Set<String> = [], recentIDs: [String] = [], preferredRestaurantID: String? = nil) {
        self.favoriteIDs = favoriteIDs
        self.recentIDs = recentIDs
        self.preferredRestaurantID = preferredRestaurantID
    }
}

public enum SearchResult: Equatable, Sendable {
    case restaurant(id: String, score: Double)
    /// `variantID` is set when the query named a size or flavour ("large fries").
    case item(restaurantID: String, itemID: String, variantID: String?, score: Double)

    public var score: Double {
        switch self {
        case let .restaurant(_, score), let .item(_, _, _, score): return score
        }
    }
}

public enum SearchText {
    private static let abbreviations: [String: String] = [
        "sm": "small", "med": "medium", "md": "medium", "lg": "large", "dbl": "double", "chz": "cheese",
        "bkfst": "breakfast", "chix": "chicken", "w": "with",
    ]
    private static let stopwords: Set<String> = ["the", "a", "an", "of", "and", "with", "for", "in", "on"]

    /// Lower-case, accent-folded tokens with common menu abbreviations expanded and filler words removed.
    public static func tokens(_ text: String) -> [String] {
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .replacingOccurrences(of: "&", with: " and ")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "\u{2019}", with: "")
            .lowercased()
        var tokens: [String] = []
        var current = ""
        func flush() {
            guard !current.isEmpty else { return }
            let expanded = abbreviations[current] ?? current
            if !stopwords.contains(expanded) { tokens.append(expanded) }
            current = ""
        }
        for character in folded {
            if character.isLetter || character.isNumber { current.append(character) } else { flush() }
        }
        flush()
        return tokens
    }

    /// Optimal string alignment distance (Levenshtein plus adjacent transposition), or `limit + 1` once it exceeds `limit`.
    public static func distance(_ a: String, _ b: String, limit: Int) -> Int {
        let s = Array(a.unicodeScalars), t = Array(b.unicodeScalars)
        if abs(s.count - t.count) > limit { return limit + 1 }
        if s.isEmpty { return t.count <= limit ? t.count : limit + 1 }
        if t.isEmpty { return s.count <= limit ? s.count : limit + 1 }

        var previous2 = [Int](repeating: 0, count: t.count + 1)
        var previous = Array(0...t.count)
        var current = [Int](repeating: 0, count: t.count + 1)
        for i in 1...s.count {
            current[0] = i
            var rowMinimum = current[0]
            for j in 1...t.count {
                let cost = s[i - 1] == t[j - 1] ? 0 : 1
                var value = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
                if i > 1, j > 1, s[i - 1] == t[j - 2], s[i - 2] == t[j - 1] {
                    value = min(value, previous2[j - 2] + 1)
                }
                current[j] = value
                rowMinimum = min(rowMinimum, value)
            }
            if rowMinimum > limit { return limit + 1 }
            (previous2, previous, current) = (previous, current, previous2)
        }
        return min(previous[t.count], limit + 1)
    }
}

public enum SearchDefaults {
    /// Words that mean the same thing on a menu. Matching through a synonym scores slightly below an exact match.
    public static let synonyms: [[String]] = [
        ["fries", "fry", "frites"],
        ["soda", "pop"],
        ["burger", "hamburger"],
        ["sandwich", "sub", "hoagie", "hero"],
        ["milkshake", "shake"],
        ["veggie", "veg", "vegetable"],
        ["donut", "doughnut"],
        ["filet", "fillet"],
        ["yogurt", "yoghurt"],
        ["mac", "macaroni"],
        ["guac", "guacamole"],
        ["bol", "bowl"],
    ]
}

/// In-memory search over a library: AND semantics across query words, with exact, synonym, prefix and typo matching,
/// restaurant names searchable from item level ("burger barn fries"), and boosts for favourites and recents.
public struct LibrarySearchIndex: Sendable {
    private enum DocKind: Sendable { case restaurant, item }

    private struct Doc: Sendable {
        let kind: DocKind
        let restaurantID: String
        let id: String
        let name: String
        let nameTokens: [String]
    }

    private struct Posting: Sendable {
        let doc: Int
        let weight: Double
        let variantID: String?
    }

    private static let nameWeight = 1.0
    private static let aliasWeight = 0.9
    private static let restaurantNameWeight = 0.7
    private static let restaurantAliasWeight = 0.6
    private static let variantWeight = 0.6
    private static let sectionWeight = 0.4

    private var docs: [Doc] = []
    private var postings: [String: [Posting]] = [:]
    private var sortedVocabulary: [String] = []
    private var vocabularyByLength: [Int: [String]] = [:]
    private var synonymClass: [String: Int] = [:]
    private var synonymMembers: [Int: [String]] = [:]

    public init(library: RestaurantLibrary, synonyms: [[String]] = SearchDefaults.synonyms) {
        for (index, group) in synonyms.enumerated() {
            synonymMembers[index] = group
            for word in group { synonymClass[word] = index }
        }

        func add(_ tokens: [String], doc: Int, weight: Double, variantID: String? = nil, into postings: inout [String: [Posting]]) {
            for token in Set(tokens) {
                postings[token, default: []].append(Posting(doc: doc, weight: weight, variantID: variantID))
            }
        }

        for restaurant in library.restaurants {
            let restaurantTokens = SearchText.tokens(restaurant.name)
            let restaurantAliasTokens = restaurant.aliases.flatMap(SearchText.tokens)

            let restaurantDoc = docs.count
            docs.append(Doc(kind: .restaurant, restaurantID: restaurant.id, id: restaurant.id, name: restaurant.name, nameTokens: restaurantTokens))
            add(restaurantTokens, doc: restaurantDoc, weight: Self.nameWeight, into: &postings)
            add(restaurantAliasTokens, doc: restaurantDoc, weight: Self.aliasWeight, into: &postings)

            for item in restaurant.items {
                let itemDoc = docs.count
                let nameTokens = SearchText.tokens(item.name)
                docs.append(Doc(kind: .item, restaurantID: restaurant.id, id: item.id, name: item.name, nameTokens: nameTokens))
                add(nameTokens, doc: itemDoc, weight: Self.nameWeight, into: &postings)
                add(item.aliases.flatMap(SearchText.tokens), doc: itemDoc, weight: Self.aliasWeight, into: &postings)
                add(restaurantTokens, doc: itemDoc, weight: Self.restaurantNameWeight, into: &postings)
                add(restaurantAliasTokens, doc: itemDoc, weight: Self.restaurantAliasWeight, into: &postings)
                add(SearchText.tokens(item.section), doc: itemDoc, weight: Self.sectionWeight, into: &postings)
                for variant in item.variants {
                    add(SearchText.tokens(variant.name), doc: itemDoc, weight: Self.variantWeight, variantID: variant.id, into: &postings)
                }
            }
        }
        sortedVocabulary = postings.keys.sorted()
        for token in sortedVocabulary { vocabularyByLength[token.count, default: []].append(token) }
    }

    public var documentCount: Int { docs.count }

    // MARK: Search

    /// - Parameters:
    ///   - restaurantID: restrict results to one restaurant's menu (in-restaurant search box).
    ///   - includeRestaurants: include restaurant-level results.
    public func search(
        _ query: String,
        limit: Int = 20,
        context: SearchContext = SearchContext(),
        restaurantID: String? = nil,
        includeRestaurants: Bool = true
    ) -> [SearchResult] {
        let queryTokens = SearchText.tokens(query)
        guard !queryTokens.isEmpty, limit > 0 else { return [] }

        // For every query word: doc -> best (weight, variant) through any matching vocabulary word.
        var perToken: [[Int: (weight: Double, variantID: String?)]] = []
        for (position, token) in queryTokens.enumerated() {
            let isLast = position == queryTokens.count - 1
            var best: [Int: (weight: Double, variantID: String?)] = [:]
            for (word, matchWeight) in candidates(for: token, isLast: isLast) {
                for posting in postings[word] ?? [] {
                    let weight = matchWeight * posting.weight
                    if weight > (best[posting.doc]?.weight ?? 0) { best[posting.doc] = (weight, posting.variantID) }
                }
            }
            if best.isEmpty { return [] }
            perToken.append(best)
        }

        guard var surviving = perToken.first.map({ Set($0.keys) }) else { return [] }
        for matches in perToken.dropFirst() { surviving.formIntersection(matches.keys) }

        var results: [SearchResult] = []
        for index in surviving {
            let doc = docs[index]
            if let restaurantID, doc.restaurantID != restaurantID { continue }
            if doc.kind == .restaurant, !includeRestaurants { continue }

            var total = 0.0
            var variants: Set<String> = []
            for matches in perToken {
                guard let match = matches[index] else { continue }
                total += match.weight
                if let variantID = match.variantID { variants.insert(variantID) }
            }
            var score = total / Double(queryTokens.count)

            if doc.nameTokens == queryTokens {
                score += 0.5
            } else if doc.nameTokens.starts(with: queryTokens) {
                score += 0.25
            }
            score -= 0.01 * Double(max(0, doc.nameTokens.count - queryTokens.count))
            if context.favoriteIDs.contains(doc.id) || context.favoriteIDs.contains(doc.restaurantID) { score += 0.15 }
            if let rank = context.recentIDs.firstIndex(of: doc.id) { score += 0.10 / Double(1 + rank) }
            if context.preferredRestaurantID == doc.restaurantID { score += 0.10 }

            switch doc.kind {
            case .restaurant:
                results.append(.restaurant(id: doc.id, score: score))
            case .item:
                results.append(.item(restaurantID: doc.restaurantID, itemID: doc.id, variantID: variants.count == 1 ? variants.first : nil, score: score))
            }
        }

        func tieBreak(_ result: SearchResult) -> String {
            switch result {
            case let .restaurant(id, _): return "0-\(id)"
            case let .item(_, itemID, _, _): return "1-\(itemID)"
            }
        }
        results.sort { lhs, rhs in
            lhs.score != rhs.score ? lhs.score > rhs.score : tieBreak(lhs) < tieBreak(rhs)
        }
        return Array(results.prefix(limit))
    }

    // MARK: Candidate vocabulary

    /// Vocabulary words a query word may stand for, with the weight of that kind of match.
    private func candidates(for token: String, isLast: Bool) -> [String: Double] {
        var found: [String: Double] = [:]
        func offer(_ word: String, _ weight: Double) { if weight > (found[word] ?? 0) { found[word] = weight } }

        if postings[token] != nil { offer(token, 1.0) }
        if let group = synonymClass[token] {
            for member in synonymMembers[group] ?? [] where postings[member] != nil { offer(member, 0.9) }
        }

        // Prefix: the word being typed, or an abbreviation.
        if token.count >= 2 {
            var low = 0, high = sortedVocabulary.count
            while low < high {
                let middle = (low + high) / 2
                if sortedVocabulary[middle] < token { low = middle + 1 } else { high = middle }
            }
            var index = low
            while index < sortedVocabulary.count, sortedVocabulary[index].hasPrefix(token) {
                offer(sortedVocabulary[index], isLast ? 0.75 : 0.5)
                index += 1
            }
        }

        // Typos: one edit for words of 4+ letters, two for 8+.
        let allowed = token.count >= 8 ? 2 : (token.count >= 4 ? 1 : 0)
        if allowed > 0 {
            for length in max(1, token.count - allowed)...(token.count + allowed) {
                for word in vocabularyByLength[length] ?? [] where found[word] == nil {
                    let distance = SearchText.distance(token, word, limit: allowed)
                    if distance <= allowed { offer(word, distance == 1 ? 0.6 : 0.45) }
                }
            }
        }
        return found
    }
}
