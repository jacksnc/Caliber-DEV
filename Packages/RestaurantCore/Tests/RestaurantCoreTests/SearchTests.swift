import XCTest
@testable import RestaurantCore

final class SearchTests: XCTestCase {
    private let library = Fixtures.library()
    private lazy var index = LibrarySearchIndex(library: library)

    private func itemIDs(_ results: [SearchResult]) -> [String] {
        results.compactMap { if case let .item(_, itemID, _, _) = $0 { return itemID } else { return nil } }
    }

    func testTokenizerFoldsAccentsExpandsAbbreviationsAndDropsFiller() {
        XCTAssertEqual(SearchText.tokens("The Café & Grill"), ["cafe", "grill"])
        XCTAssertEqual(SearchText.tokens("Dbl Chz Bkfst w/ Eggs"), ["double", "cheese", "breakfast", "eggs"])
        XCTAssertEqual(SearchText.tokens("Mc'Allister's  Sm."), ["mcallisters", "small"])
        XCTAssertEqual(SearchText.tokens("  "), [])
        XCTAssertEqual(SearchText.tokens("Latté"), ["latte"])
    }

    func testEditDistance() {
        XCTAssertEqual(SearchText.distance("kitten", "sitting", limit: 5), 3)
        XCTAssertEqual(SearchText.distance("ab", "ba", limit: 2), 1, "adjacent transposition counts once")
        XCTAssertEqual(SearchText.distance("burger", "burgr", limit: 2), 1)
        XCTAssertEqual(SearchText.distance("same", "same", limit: 2), 0)
        XCTAssertEqual(SearchText.distance("abcdef", "uvwxyz", limit: 2), 3, "returns limit + 1 once exceeded")
        XCTAssertEqual(SearchText.distance("", "ab", limit: 2), 2)
        XCTAssertEqual(SearchText.distance("", "abcd", limit: 2), 3)
    }

    func testExactNameBeatsEverythingElse() {
        let results = index.search("fries")
        XCTAssertEqual(itemIDs(results).first, "burger-barn/fries")
        XCTAssertEqual(itemIDs(results).count, 1, "only fries match the word fries")
    }

    func testAliasesSynonymsAndRestaurantContext() {
        XCTAssertEqual(itemIDs(index.search("french fries")).first, "burger-barn/fries")
        XCTAssertEqual(itemIDs(index.search("soda")).first, "burger-barn/cola", "alias")
        XCTAssertEqual(itemIDs(index.search("pop")).first, "burger-barn/cola", "alias")
        XCTAssertEqual(itemIDs(index.search("frites")).first, "burger-barn/fries", "synonym")
        XCTAssertEqual(itemIDs(index.search("milkshake")).first, "burger-barn/chocolate-shake")
        XCTAssertEqual(itemIDs(index.search("burger barn fries")).first, "burger-barn/fries", "restaurant name narrows the item")
        XCTAssertEqual(itemIDs(index.search("burger barn fries")).count, 1)
        XCTAssertEqual(itemIDs(index.search("dbl barn")).first, "burger-barn/double-barn-burger")
        XCTAssertEqual(itemIDs(index.search("chips guac")).first, "taco-tangent/chips-and-guac", "stopwords ignored")
        XCTAssertEqual(itemIDs(index.search("chips and guac")).first, "taco-tangent/chips-and-guac")
        XCTAssertEqual(itemIDs(index.search("guacamole")).first, "taco-tangent/chips-and-guac", "synonym of guac")
    }

    func testVariantInQueryIsReported() {
        guard case let .item(_, itemID, variantID, _)? = index.search("large fries").first else { return XCTFail() }
        XCTAssertEqual(itemID, "burger-barn/fries")
        XCTAssertEqual(variantID, "large")
        guard case let .item(_, _, plain, _)? = index.search("fries").first else { return XCTFail() }
        XCTAssertNil(plain)
        guard case let .item(_, latte, grande, _)? = index.search("grande latte").first else { return XCTFail() }
        XCTAssertEqual(latte, "bean-there-coffee/latte")
        XCTAssertEqual(grande, "grande")
        guard case let .item(_, _, ambiguous, _)? = index.search("small large cola").first else { return XCTFail("both sizes named") }
        XCTAssertNil(ambiguous, "two different sizes in the query give no single variant")
    }

    func testTypingAndTypos() {
        XCTAssertEqual(itemIDs(index.search("choc")).first, "burger-barn/chocolate-shake", "prefix of the word being typed")
        XCTAssertEqual(itemIDs(index.search("burgr", restaurantID: "burger-barn", includeRestaurants: false)).count, 8, "all Burger Barn items via the restaurant name, typo tolerated")
        XCTAssertEqual(itemIDs(index.search("clasic barn")).first, "burger-barn/classic-barn-burger")
        XCTAssertTrue(itemIDs(index.search("tacos")).contains("taco-tangent/veggie-taco"), "plural typo")
        XCTAssertEqual(itemIDs(index.search("latte", restaurantID: "bean-there-coffee")), ["bean-there-coffee/latte"])
        XCTAssertEqual(itemIDs(index.search("lattee")).first, "bean-there-coffee/latte")
        XCTAssertEqual(index.search("xyzzy"), [])
        XCTAssertEqual(index.search(""), [])
        XCTAssertEqual(index.search("fries", limit: 0), [])
        XCTAssertEqual(itemIDs(index.search("Latté")).first, "bean-there-coffee/latte")
    }

    func testShortWordsAreNotFuzzed() {
        // "cat" must not match "cola" or "taco": words under four letters need an exact or prefix match.
        XCTAssertEqual(index.search("cat"), [])
    }

    func testRestaurantResults() {
        guard case let .restaurant(id, _)? = index.search("taco").first else { return XCTFail("restaurant ranks first for its own name") }
        XCTAssertEqual(id, "taco-tangent")
        XCTAssertFalse(index.search("taco", includeRestaurants: false).contains { if case .restaurant = $0 { return true } else { return false } })
        guard case let .restaurant(barn, _)? = index.search("burger barn").first else { return XCTFail() }
        XCTAssertEqual(barn, "burger-barn")
        guard case let .restaurant(coffee, _)? = index.search("bean there").first else { return XCTFail() }
        XCTAssertEqual(coffee, "bean-there-coffee")
    }

    func testScopedSearchOnlyReturnsThatMenu() {
        let results = index.search("burger", restaurantID: "taco-tangent")
        XCTAssertTrue(results.isEmpty, "no burger on this menu: \(results)")
        XCTAssertFalse(itemIDs(index.search("tacos", restaurantID: "taco-tangent")).isEmpty)
    }

    func testFavoritesRecentsAndPreferredRestaurantBoostRanking() {
        let plain = itemIDs(index.search("burger", includeRestaurants: false))
        XCTAssertEqual(Array(plain.prefix(3)), ["burger-barn/classic-barn-burger", "burger-barn/double-barn-burger", "burger-barn/garden-veggie-burger"],
                       "ties break by id")
        let boosted = itemIDs(index.search("burger", context: SearchContext(favoriteIDs: ["burger-barn/garden-veggie-burger"]), includeRestaurants: false))
        XCTAssertEqual(boosted.first, "burger-barn/garden-veggie-burger")
        let recent = itemIDs(index.search("burger", context: SearchContext(recentIDs: ["burger-barn/double-barn-burger"]), includeRestaurants: false))
        XCTAssertEqual(recent.first, "burger-barn/double-barn-burger")
        let nearby = itemIDs(index.search("taco", context: SearchContext(preferredRestaurantID: "burger-barn"), includeRestaurants: false))
        XCTAssertFalse(nearby.isEmpty)
    }

    func testLimitAndDeterminism() {
        let first = index.search("a", limit: 5)
        XCTAssertLessThanOrEqual(first.count, 5)
        XCTAssertEqual(first, index.search("a", limit: 5))
        XCTAssertEqual(LibrarySearchIndex(library: library).search("burger"), index.search("burger"))
        XCTAssertEqual(index.documentCount, 3 + 15)
    }

    func testCustomSynonyms() {
        let custom = LibrarySearchIndex(library: library, synonyms: [["fries", "spuds"]])
        XCTAssertEqual(itemIDs(custom.search("spuds")).first, "burger-barn/fries")
        XCTAssertFalse(itemIDs(index.search("hamburger")).isEmpty, "default synonym: hamburger means burger")
        XCTAssertTrue(itemIDs(custom.search("hamburger")).isEmpty, "defaults are replaced, not merged")
    }
}
