import Foundation

/// Advisory allergen detection from ingredient text. It finds allergens that ARE mentioned; it can never prove a
/// food is free of one, so the app must always show "check the package" next to any allergen result.
public enum AllergenDetector {
    private static let keywords: [Allergen: [String]] = [
        .milk: ["milk", "whey", "casein", "caseinate", "lactose", "butter", "buttermilk", "cream", "cheese", "yogurt", "yoghurt", "ghee", "custard", "lactalbumin"],
        .egg: ["egg", "eggs", "albumin", "albumen", "lysozyme", "mayonnaise", "meringue", "ovalbumin"],
        .fish: ["fish", "anchovy", "anchovies", "salmon", "tuna", "cod", "tilapia", "haddock", "pollock", "sardine", "sardines", "trout", "mackerel", "herring", "bass"],
        .crustaceanShellfish: ["shrimp", "prawn", "prawns", "crab", "lobster", "crayfish", "crawfish", "krill"],
        .mollusc: ["clam", "clams", "oyster", "oysters", "mussel", "mussels", "scallop", "scallops", "squid", "octopus", "abalone", "snail"],
        .treeNut: ["almond", "almonds", "walnut", "walnuts", "pecan", "pecans", "cashew", "cashews", "pistachio", "pistachios", "hazelnut", "hazelnuts", "macadamia", "praline"],
        .peanut: ["peanut", "peanuts", "groundnut", "groundnuts", "arachis"],
        .wheat: ["wheat", "semolina", "spelt", "farina", "durum", "einkorn", "kamut", "bulgur", "couscous"],
        .gluten: ["wheat", "barley", "rye", "triticale", "gluten", "seitan", "malt", "spelt", "semolina", "farina", "durum"],
        .soy: ["soy", "soya", "soybean", "soybeans", "edamame", "tofu", "miso", "tempeh"],
        .sesame: ["sesame", "tahini"],
        .celery: ["celery", "celeriac"],
        .mustard: ["mustard"],
        .lupin: ["lupin", "lupine"],
        .sulphite: ["sulfite", "sulfites", "sulphite", "sulphites", "metabisulfite", "metabisulphite"],
    ]

    /// Multi-word phrases that mean wheat flour on a US label.
    private static let wheatPhrases = ["enriched flour", "bleached flour", "unbleached flour", "all-purpose flour", "all purpose flour", "bread flour"]
    private static let sulphitePhrases = ["sulfur dioxide", "sulphur dioxide"]
    private static let soyPhrases = ["soy lecithin", "soya lecithin"]

    /// Compound names that contain an allergen word but are not that allergen.
    private static let exclusions = [
        "cocoa butter", "cacao butter", "shea butter", "peanut butter", "almond butter", "cashew butter", "nut butter", "seed butter",
        "sunflower butter", "coconut cream", "cream of tartar", "coconut milk", "almond milk", "soy milk", "oat milk", "rice milk",
        "butternut", "eggplant",
    ]

    public static func possibleAllergens(in ingredients: String) -> Set<Allergen> {
        var text = " " + ingredients.lowercased() + " "
        // Peanut butter is a peanut (and tree-nut butters are tree nuts) even though "butter" is excluded as milk.
        var found: Set<Allergen> = []
        if text.contains("peanut butter") { found.insert(.peanut) }
        for nutButter in ["almond butter", "cashew butter"] where text.contains(nutButter) { found.insert(.treeNut) }
        if text.contains("soy milk") { found.insert(.soy) }
        if text.contains("almond milk") { found.insert(.treeNut) }

        for phrase in exclusions { text = text.replacingOccurrences(of: phrase, with: " ") }

        let words = Set(tokenize(text))
        for (allergen, list) in keywords where list.contains(where: words.contains) { found.insert(allergen) }
        if wheatPhrases.contains(where: text.contains) { found.insert(.wheat); found.insert(.gluten) }
        if sulphitePhrases.contains(where: text.contains) { found.insert(.sulphite) }
        if soyPhrases.contains(where: text.contains) { found.insert(.soy) }
        // "Gluten" family: wheat always implies gluten.
        if found.contains(.wheat) { found.insert(.gluten) }
        return found
    }

    private static func tokenize(_ text: String) -> [String] {
        text.split(whereSeparator: { !($0.isLetter || $0.isNumber) }).map(String.init)
    }
}

enum AllergenTags {
    /// Open Food Facts taxonomy tags (`en:milk`, `en:nuts`, ...).
    static let openFoodFacts: [String: Allergen] = [
        "en:milk": .milk, "en:eggs": .egg, "en:fish": .fish, "en:crustaceans": .crustaceanShellfish,
        "en:molluscs": .mollusc, "en:nuts": .treeNut, "en:peanuts": .peanut, "en:gluten": .gluten,
        "en:wheat": .wheat, "en:soybeans": .soy, "en:sesame-seeds": .sesame, "en:celery": .celery,
        "en:mustard": .mustard, "en:lupin": .lupin, "en:sulphur-dioxide-and-sulphites": .sulphite,
    ]

    static func fromOpenFoodFacts(_ tags: [String]) -> Set<Allergen> {
        Set(tags.compactMap { openFoodFacts[$0.lowercased()] })
    }
}
