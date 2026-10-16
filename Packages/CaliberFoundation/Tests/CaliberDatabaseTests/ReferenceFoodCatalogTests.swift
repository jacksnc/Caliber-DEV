import CryptoKit
import Foundation
import GRDB
import Testing

@testable import CaliberDatabase

private struct CatalogFixture {
  let directory: URL
  let url: URL

  var sha256: String {
    get throws {
      SHA256.hash(data: try Data(contentsOf: url)).map { String(format: "%02x", $0) }.joined()
    }
  }

  func open() throws -> ReferenceFoodCatalog {
    try ReferenceFoodCatalog(url: url, expectedSHA256: sha256)
  }

  func change(_ sql: String) throws {
    let queue = try DatabaseQueue(path: url.path)
    try queue.write { db in try db.execute(sql: sql) }
  }
}

/// These are fictional test rows, not USDA nutrition claims. Only the source provenance pins
/// match the production contract; every food, measurement and nutrient below is synthetic.
private func catalogFixture(foodCount: Int = 8) throws -> CatalogFixture {
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
    "CaliberReferenceCatalogTests-" + UUID().uuidString)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  let url = directory.appendingPathComponent("fixture.sqlite")
  let queue = try DatabaseQueue(path: url.path)
  try queue.write { db in
    try db.execute(
      sql: """
        PRAGMA application_id=1128352838;
        PRAGMA user_version=1;
        CREATE TABLE catalog_metadata(key TEXT PRIMARY KEY,value TEXT NOT NULL);
        CREATE TABLE catalog_sources(id TEXT PRIMARY KEY,name TEXT,data_type TEXT,release TEXT,
          archive_url TEXT,archive_sha256 TEXT,license TEXT);
        CREATE TABLE catalog_foods(id TEXT PRIMARY KEY,source_id TEXT REFERENCES catalog_sources,
          fdc_id INTEGER UNIQUE,name TEXT,publication_date TEXT,energy_nutrient_id INTEGER,
          calories REAL,protein_g REAL,carbohydrate_g REAL,fat_g REAL,category TEXT,search_name TEXT);
        CREATE TABLE catalog_servings(id TEXT PRIMARY KEY,food_id TEXT REFERENCES catalog_foods,
          label TEXT,gram_weight REAL,sort_order INTEGER);
        CREATE INDEX catalog_food_name ON catalog_foods(search_name,source_id,fdc_id,id);
        CREATE INDEX catalog_serving_food ON catalog_servings(food_id,sort_order,id);
        CREATE VIRTUAL TABLE food_search USING fts5(food_id UNINDEXED,name,
          tokenize='unicode61 remove_diacritics 2',prefix='2 3 4');
        INSERT INTO catalog_metadata VALUES ('schema_version','1');
        INSERT INTO catalog_sources VALUES ('usda-foundation:2026-04-30','USDA FoodData Central','Foundation',
          '2026-04-30',
          'https://fdc.nal.usda.gov/fdc-datasets/FoodData_Central_foundation_food_json_2026-04-30.zip',
          '186e988ec542e913f51ef62b86a47758e8cdd0d1dc3889e7b055581f3c09c77a','CC0-1.0');
        INSERT INTO catalog_sources VALUES ('usda-sr-legacy:2018-04','USDA FoodData Central','SR Legacy',
          '2018-04',
          'https://fdc.nal.usda.gov/fdc-datasets/FoodData_Central_sr_legacy_food_json_2018-04.zip',
          '0fe8ae486a2c8eb42cb96413f058deb51863a46c8fb8eeb4b1fb45006dd338ef','CC0-1.0');
        """
    )
    let names = [
      "Egg", "Egg", "Eggplant", "Yogurt, Greek plain", "Café yogurt", "Cafe yogurt", "Nonfat milk",
      "Milk, nonfat",
    ]
    for index in 1...foodCount {
      let name = index <= names.count ? names[index - 1] : "Fictional food \(index)"
      let prefix = index == 2 ? "usda-sr-legacy" : "usda-foundation"
      let source = prefix + (index == 2 ? ":2018-04" : ":2026-04-30")
      let id = prefix + ":\(index)"
      let searchName = name.folding(
        options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
        locale: Locale(identifier: "en_US_POSIX")
      ).lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted)
        .filter { !$0.isEmpty }.joined(separator: " ")
      try db.execute(
        sql:
          "INSERT INTO catalog_foods VALUES (?,?,?,?,'2025-01-01',2048,200.25,10.125,20.5,3.75,'Test category',?)",
        arguments: [id, source, index, name, searchName])
      try db.execute(sql: "INSERT INTO food_search VALUES (?,?)", arguments: [id, searchName])
    }
    try db.execute(
      sql: """
        INSERT INTO catalog_servings VALUES ('fictional-cup','usda-foundation:1','1 fictional cup',123.5,1);
        INSERT INTO catalog_servings VALUES ('fictional-half','usda-foundation:1','1 fictional half',61.75,0);
        """
    )
  }
  return CatalogFixture(directory: directory, url: url)
}

@Test func referenceCatalogReadsExactNutritionProvenanceAndMeasuredServings() throws {
  let fixture = try catalogFixture()
  defer { try? FileManager.default.removeItem(at: fixture.directory) }
  let catalog = try fixture.open()
  #expect(try catalog.foodCount == 8)
  #expect(try catalog.servingCount == 2)
  let food = try #require(try catalog.entry(id: "usda-foundation:1"))
  #expect(food.fdcID == 1)
  #expect(food.name == "Egg")
  #expect(food.publicationDate == "2025-01-01")
  #expect(food.energyNutrientID == 2048)
  #expect(food.calories == 200.25)
  #expect(food.proteinGrams == 10.125)
  #expect(food.carbGrams == 20.5)
  #expect(food.fatGrams == 3.75)
  #expect(food.category == "Test category")
  #expect(food.source.id == "usda-foundation:2026-04-30")
  #expect(food.source.release == "2026-04-30")
  #expect(food.source.license == "CC0-1.0")
  #expect(food.servings.map(\.id) == ["fictional-half", "fictional-cup"])
  #expect(food.servings.map(\.gramWeight) == [61.75, 123.5])
  #expect(try catalog.entry(id: "usda-sr-legacy:2")?.source.dataType == "SR Legacy")
  #expect(try catalog.entry(id: "usda-foundation:3")?.servings.isEmpty == true)
}

@Test func referenceCatalogDoesNotWriteCreateSidecarsOrChangeOriginalBytes() throws {
  let fixture = try catalogFixture()
  defer { try? FileManager.default.removeItem(at: fixture.directory) }
  let bytes = try Data(contentsOf: fixture.url)
  let listing = try FileManager.default.contentsOfDirectory(atPath: fixture.directory.path).sorted()
  for _ in 0..<3 {
    let catalog = try fixture.open()
    #expect(try catalog.search(query: "egg").count == 3)
    #expect(try catalog.entry(id: "usda-foundation:1") != nil)
  }
  #expect(try Data(contentsOf: fixture.url) == bytes)
  #expect(
    try FileManager.default.contentsOfDirectory(atPath: fixture.directory.path).sorted() == listing)
}

@Test func referenceCatalogSearchUsesWordPrefixesAndDeterministicRanking() throws {
  let fixture = try catalogFixture()
  defer { try? FileManager.default.removeItem(at: fixture.directory) }
  let catalog = try fixture.open()
  #expect(
    try catalog.search(query: "egg").map(\.id) == [
      "usda-foundation:1", "usda-sr-legacy:2", "usda-foundation:3",
    ])
  #expect(
    try catalog.search(query: "eg").map(\.id) == [
      "usda-foundation:1", "usda-foundation:3", "usda-sr-legacy:2",
    ])
  #expect(try catalog.search(query: "gpl").isEmpty)
  #expect(try catalog.search(query: "ＧＲＥＥＫ! yóg").map(\.fdcID) == [4])
  #expect(try catalog.search(query: "yog greek").map(\.fdcID) == [4])
  #expect(try catalog.search(query: "cafe").map(\.fdcID) == [5, 6])
  #expect(try catalog.search(query: "nonfat milk").map(\.fdcID).first == 7)
  #expect(try catalog.search(query: "milk nonfat").map(\.fdcID).first == 8)
  #expect(try catalog.search(query: "notfound").isEmpty)
}

@Test func referenceCatalogBoundsQueriesAndNeverTreatsInputAsSQLOrFTSSyntax() throws {
  let fixture = try catalogFixture(foodCount: 250)
  defer { try? FileManager.default.removeItem(at: fixture.directory) }
  let catalog = try fixture.open()
  #expect(try catalog.search(query: "", limit: Int.max).count == 200)
  #expect(try catalog.search(query: "", limit: 0).isEmpty)
  #expect(try catalog.search(query: "egg", limit: -1).isEmpty)
  #expect(try catalog.search(query: "food", limit: 1).count == 1)
  #expect(try catalog.search(query: String(repeating: "x", count: 513)).isEmpty)
  #expect(try catalog.search(query: String(repeating: "a ", count: 17)).isEmpty)
  #expect(try catalog.search(query: String(repeating: "x", count: 65)).isEmpty)
  #expect(try catalog.search(query: "egg OR name:milk").isEmpty)
  #expect(try catalog.search(query: "\"; DROP TABLE catalog_foods; --").isEmpty)
  #expect(try catalog.search(query: "egg\"*").count == 3)
  #expect(try catalog.foodCount == 250)
  #expect(try catalog.entry(id: "usda-foundation:1 OR 1=1") == nil)
  #expect(try catalog.entry(id: "usda-foundation:01") == nil)
  #expect(try catalog.entry(id: "usda-foundation:99999") == nil)
}

@Test(arguments: [
  "PRAGMA application_id=0", "PRAGMA user_version=2",
  "UPDATE catalog_metadata SET value='2'", "DROP TABLE catalog_metadata",
  "DROP INDEX catalog_food_name", "DROP INDEX catalog_serving_food",
  "CREATE TABLE fake_search AS SELECT * FROM food_search; DROP TABLE food_search; ALTER TABLE fake_search RENAME TO food_search",
  "CREATE VIEW unexpected_view AS SELECT * FROM catalog_foods",
  "UPDATE catalog_sources SET license='unclear' WHERE id='usda-foundation:2026-04-30'",
  "UPDATE catalog_sources SET data_type='Branded' WHERE id='usda-foundation:2026-04-30'",
  "UPDATE catalog_sources SET release='2025-04' WHERE id='usda-foundation:2026-04-30'",
  "UPDATE catalog_sources SET archive_sha256=printf('%064d',0) WHERE id='usda-foundation:2026-04-30'",
  "UPDATE catalog_sources SET archive_url='https://example.invalid/archive.zip' WHERE id='usda-foundation:2026-04-30'",
  "UPDATE catalog_sources SET name=NULL WHERE id='usda-foundation:2026-04-30'",
  "UPDATE catalog_foods SET source_id='unknown' WHERE fdc_id=1",
  "UPDATE catalog_foods SET id='usda-foundation:01' WHERE fdc_id=1",
  "UPDATE catalog_foods SET name='' WHERE fdc_id=1",
  "UPDATE catalog_foods SET publication_date='' WHERE fdc_id=1",
  "UPDATE catalog_foods SET energy_nutrient_id=999 WHERE fdc_id=1",
  "UPDATE catalog_foods SET calories=-1 WHERE fdc_id=1",
  "UPDATE catalog_foods SET calories=1000.1 WHERE fdc_id=1",
  "UPDATE catalog_foods SET calories=1e999 WHERE fdc_id=1",
  "UPDATE catalog_foods SET calories=NULL WHERE fdc_id=1",
  "UPDATE catalog_foods SET protein_g=100.1 WHERE fdc_id=1",
  "UPDATE catalog_foods SET carbohydrate_g=-0.1 WHERE fdc_id=1",
  "UPDATE catalog_foods SET fat_g=NULL WHERE fdc_id=1",
  "UPDATE catalog_foods SET search_name='different name' WHERE fdc_id=1",
  "UPDATE catalog_servings SET gram_weight=0 WHERE id='fictional-cup'",
  "UPDATE catalog_servings SET gram_weight=1000000.1 WHERE id='fictional-cup'",
  "UPDATE catalog_servings SET label='' WHERE id='fictional-cup'",
  "UPDATE catalog_servings SET food_id='missing' WHERE id='fictional-cup'",
  "UPDATE catalog_servings SET sort_order=-1 WHERE id='fictional-cup'",
  "UPDATE food_search SET name='wrong words' WHERE food_id='usda-foundation:1'",
  "DELETE FROM food_search WHERE food_id='usda-foundation:1'",
  "INSERT INTO food_search VALUES ('usda-foundation:1','egg')",
])
func referenceCatalogRejectsMalformedRowsEvenWithMatchingFileHash(_ mutation: String) throws {
  let fixture = try catalogFixture()
  defer { try? FileManager.default.removeItem(at: fixture.directory) }
  // Deliberately disable foreign-key enforcement for these corruption fixtures.
  var configuration = Configuration()
  configuration.foreignKeysEnabled = false
  let queue = try DatabaseQueue(path: fixture.url.path, configuration: configuration)
  try queue.write { db in
    try db.execute(sql: "PRAGMA defer_foreign_keys=ON")
    try db.execute(sql: mutation)
  }
  #expect(throws: ReferenceFoodCatalogError.invalidData) { try fixture.open() }
}

@Test func referenceCatalogRejectsMissingWrongHashCorruptOversizedAndSidecarFiles() throws {
  let fixture = try catalogFixture()
  defer { try? FileManager.default.removeItem(at: fixture.directory) }
  #expect(throws: ReferenceFoodCatalogError.invalidData) {
    try ReferenceFoodCatalog(url: fixture.url, expectedSHA256: String(repeating: "0", count: 64))
  }
  #expect(throws: ReferenceFoodCatalogError.invalidData) {
    try ReferenceFoodCatalog(url: fixture.url, expectedSHA256: "invalid")
  }
  #expect(throws: ReferenceFoodCatalogError.unavailable) {
    try ReferenceFoodCatalog(
      url: fixture.directory.appendingPathComponent("missing.sqlite"),
      expectedSHA256: fixture.sha256)
  }
  let sidecar = URL(fileURLWithPath: fixture.url.path + "-wal")
  try Data().write(to: sidecar)
  #expect(throws: ReferenceFoodCatalogError.invalidData) { try fixture.open() }
  try FileManager.default.removeItem(at: sidecar)
  let symlink = fixture.directory.appendingPathComponent("link.sqlite")
  try FileManager.default.createSymbolicLink(at: symlink, withDestinationURL: fixture.url)
  #expect(throws: ReferenceFoodCatalogError.invalidData) {
    try ReferenceFoodCatalog(url: symlink, expectedSHA256: fixture.sha256)
  }
  try Data("not SQLite".utf8).write(to: fixture.url)
  #expect(throws: ReferenceFoodCatalogError.invalidData) { try fixture.open() }
  let handle = try FileHandle(forWritingTo: fixture.url)
  try handle.truncate(atOffset: 20 * 1_024 * 1_024 + 1)
  try handle.close()
  #expect(throws: ReferenceFoodCatalogError.invalidData) { try fixture.open() }
}

/// An optional production-sized smoke run. Normal package tests only need synthetic fixtures.
@Test(.enabled(if: ProcessInfo.processInfo.environment["CALIBER_REFERENCE_CATALOG_PATH"] != nil))
func referenceCatalogFullDatasetMeasurementWhenSupplied() throws {
  let environment = ProcessInfo.processInfo.environment
  let path = try #require(environment["CALIBER_REFERENCE_CATALOG_PATH"])
  let hash = try #require(environment["CALIBER_REFERENCE_CATALOG_SHA256"])
  let start = ContinuousClock.now
  let catalog = try ReferenceFoodCatalog(url: URL(fileURLWithPath: path), expectedSHA256: hash)
  let opened = ContinuousClock.now
  #expect(try catalog.foodCount > 1_000)
  #expect(try catalog.servingCount > 1_000)
  for _ in 0..<10 {
    #expect(try !catalog.search(query: "egg").isEmpty)
    #expect(try !catalog.search(query: "oats rolled").isEmpty)
    #expect(try !catalog.search(query: "chicken breast").isEmpty)
  }
  let end = ContinuousClock.now
  print(
    "REFERENCE CATALOG open+full validation: \(start.duration(to: opened)); 30 searches: \(opened.duration(to: end))"
  )
}
