import CryptoKit
import Foundation
import GRDB
import Testing

@testable import CaliberDatabase

private struct PackagedFixture {
  let directory: URL
  let url: URL

  var hash: String {
    get throws {
      SHA256.hash(data: try Data(contentsOf: url)).map { String(format: "%02x", $0) }.joined()
    }
  }

  func open() throws -> PackagedFoodCatalog {
    try PackagedFoodCatalog(url: url, expectedSHA256: hash)
  }

  func change(_ sql: String) throws {
    var configuration = Configuration()
    configuration.foreignKeysEnabled = false
    let queue = try DatabaseQueue(path: url.path, configuration: configuration)
    try queue.write { db in try db.execute(sql: sql) }
  }
}

private func packagedGTIN(_ body: Int) -> String {
  let digits = String(format: "%013d", body)
  let sum = digits.utf8.enumerated().reduce(0) { result, pair in
    result + Int(pair.element - 48) * (pair.offset.isMultiple(of: 2) ? 3 : 1)
  }
  return digits + String((10 - sum % 10) % 10)
}

/// All barcode identities, foods and nutrition are fictional. Official source pins only
/// establish the contract the reader expects; this fixture makes no USDA food claims.
private func packagedFixture(count: Int = 3, hasForeignKey: Bool = true) throws -> PackagedFixture {
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
    "CaliberPackagedCatalogTests-" + UUID().uuidString)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  let url = directory.appendingPathComponent("packaged.sqlite")
  let queue = try DatabaseQueue(path: url.path)
  try queue.write { db in
    try db.execute(
      sql: """
        PRAGMA application_id=1128352848;
        PRAGMA user_version=1;
        CREATE TABLE packaged_metadata(key TEXT PRIMARY KEY,value TEXT);
        CREATE TABLE packaged_sources(id TEXT PRIMARY KEY,name TEXT,data_type TEXT,release TEXT,
          archive_url TEXT,archive_sha256 TEXT,license TEXT);
        CREATE TABLE packaged_products(gtin14 TEXT PRIMARY KEY,fdc_id INTEGER UNIQUE,
          name TEXT NOT NULL,brand TEXT NOT NULL,publication_date TEXT NOT NULL,modified_date TEXT NOT NULL,
          calories REAL,protein_g REAL,carbohydrate_g REAL,fat_g REAL,basis_unit TEXT NOT NULL,
          serving_quantity REAL,serving_unit TEXT,serving_label TEXT,source_id TEXT NOT NULL \(hasForeignKey ? "REFERENCES packaged_sources(id)" : ""));
        INSERT INTO packaged_metadata VALUES ('schema_version','1');
        INSERT INTO packaged_sources VALUES ('usda-branded:2026-04','USDA FoodData Central','Branded','2026-04',
          'https://fdc.nal.usda.gov/fdc-datasets/FoodData_Central_branded_food_csv_2026-04-30.zip',
          '26050a5d03197469813754743a21ee0fad4ccf22b6aac2a995846a987719fc49','CC0-1.0');
        """
    )
    for index in 1...max(count, 1) where count > 0 {
      let volume = index == 2
      try db.execute(
        sql: """
          INSERT INTO packaged_products VALUES (?,?,?,?,'2026-04-30',?,200.25,10.125,20.5,3.75,?,?,?,?,
            'usda-branded:2026-04')
          """,
        arguments: [
          packagedGTIN(index), index, "Fictional packaged food \(index)",
          index == 3 ? "" : "Fictional Brand",
          index == 3 ? "" : "2024-02-29", volume ? "mL" : "g", volume ? 240.0 : 28.5,
          volume ? "mL" : "g", volume ? nil : "1 fictional source serving",
        ])
    }
  }
  return PackagedFixture(directory: directory, url: url)
}

@Test func packagedCatalogReadsSourceAndExplicitMassVolumeBasis() throws {
  let fixture = try packagedFixture()
  defer { try? FileManager.default.removeItem(at: fixture.directory) }
  let catalog = try fixture.open()
  #expect(try catalog.foodCount == 3)
  let mass = try #require(try catalog.product(gtin14: packagedGTIN(1)))
  #expect(mass.gtin14 == "00000000000017")
  #expect(mass.fdcID == 1)
  #expect(mass.name == "Fictional packaged food 1")
  #expect(mass.brand == "Fictional Brand")
  #expect(mass.publicationDate == "2026-04-30")
  #expect(mass.modifiedDate == "2024-02-29")
  #expect(mass.calories == 200.25)
  #expect(mass.proteinGrams == 10.125)
  #expect(mass.carbGrams == 20.5)
  #expect(mass.fatGrams == 3.75)
  #expect(mass.basisUnit == "g")
  #expect(mass.servingQuantity == 28.5)
  #expect(mass.servingUnit == "g")
  #expect(mass.servingLabel == "1 fictional source serving")
  #expect(mass.source.id == "usda-branded:2026-04")
  #expect(mass.source.dataType == "Branded")
  #expect(mass.source.release == "2026-04")
  #expect(mass.source.license == "CC0-1.0")
  let volume = try #require(try catalog.product(gtin14: packagedGTIN(2)))
  #expect(volume.basisUnit == "mL")
  #expect(volume.servingQuantity == 240)
  #expect(volume.servingUnit == "mL")
  #expect(volume.servingLabel == nil)
  #expect(volume.calories == mass.calories)
  let missingOptionalSourceText = try #require(try catalog.product(gtin14: packagedGTIN(3)))
  #expect(missingOptionalSourceText.brand.isEmpty)
  #expect(missingOptionalSourceText.modifiedDate.isEmpty)
}

@Test func packagedCatalogUsesVolumeBoundsWithoutAssumingLiquidDensity() throws {
  let fixture = try packagedFixture()
  defer { try? FileManager.default.removeItem(at: fixture.directory) }
  try fixture.change(
    "UPDATE packaged_products SET calories=1500,protein_g=150 WHERE basis_unit='mL'")
  let catalog = try fixture.open()
  let product = try #require(try catalog.product(gtin14: packagedGTIN(2)))
  #expect(product.basisUnit == "mL")
  #expect(product.calories == 1500)
  #expect(product.proteinGrams == 150)
  #expect(product.servingQuantity == 240)
}

@Test func packagedCatalogAcceptsCanonicalUPCAndEANIdentitiesWithoutAliasingShortForms() throws {
  let fixture = try packagedFixture()
  defer { try? FileManager.default.removeItem(at: fixture.directory) }
  try fixture.change(
    "UPDATE packaged_products SET gtin14='00036000291452' WHERE fdc_id=1; UPDATE packaged_products SET gtin14='04006381333931' WHERE fdc_id=2"
  )
  let catalog = try fixture.open()
  #expect(try catalog.product(gtin14: "00036000291452")?.fdcID == 1)
  #expect(try catalog.product(gtin14: "04006381333931")?.fdcID == 2)
  #expect(try catalog.product(gtin14: "036000291452") == nil)
  #expect(try catalog.product(gtin14: "4006381333931") == nil)
}

@Test func packagedCatalogRequiresDeclaredSourceForeignKey() throws {
  let fixture = try packagedFixture(hasForeignKey: false)
  defer { try? FileManager.default.removeItem(at: fixture.directory) }
  #expect(throws: PackagedFoodCatalogError.invalidData) { try fixture.open() }
}

@Test func packagedCatalogReopensWithoutChangingBytesOrCreatingSidecars() throws {
  let fixture = try packagedFixture()
  defer { try? FileManager.default.removeItem(at: fixture.directory) }
  let original = try Data(contentsOf: fixture.url)
  let listing = try FileManager.default.contentsOfDirectory(atPath: fixture.directory.path).sorted()
  for _ in 0..<3 {
    let catalog = try fixture.open()
    #expect(try catalog.foodCount == 3)
    #expect(try catalog.product(gtin14: packagedGTIN(1)) != nil)
    #expect(try catalog.product(gtin14: packagedGTIN(99)) == nil)
  }
  #expect(try Data(contentsOf: fixture.url) == original)
  #expect(
    try FileManager.default.contentsOfDirectory(atPath: fixture.directory.path).sorted() == listing)
}

@Test(arguments: [
  "", "012345678905", "00000000000018", "00000000000000", "００００００００００００１７", "00000000000017 OR 1=1",
  "00000000000017; DROP TABLE packaged_products", " 00000000000017",
])
func packagedCatalogRejectsNoncanonicalLookupWithoutSQLInterpolation(_ code: String) throws {
  let fixture = try packagedFixture()
  defer { try? FileManager.default.removeItem(at: fixture.directory) }
  let catalog = try fixture.open()
  #expect(try catalog.product(gtin14: code) == nil)
  #expect(try catalog.foodCount == 3)
}

@Test(arguments: [
  "PRAGMA application_id=0", "PRAGMA user_version=2",
  "UPDATE packaged_metadata SET value='2'", "DROP TABLE packaged_metadata",
  "CREATE VIEW unexpected_view AS SELECT * FROM packaged_products",
  "CREATE TABLE new_products AS SELECT * FROM packaged_products; DROP TABLE packaged_products; ALTER TABLE new_products RENAME TO packaged_products",
  "UPDATE packaged_sources SET id='unknown'", "UPDATE packaged_sources SET name='Unknown source'",
  "UPDATE packaged_sources SET data_type='Foundation'",
  "UPDATE packaged_sources SET release='2025-04'",
  "UPDATE packaged_sources SET archive_url='https://example.invalid/archive.zip'",
  "UPDATE packaged_sources SET archive_sha256=printf('%064d',0)",
  "UPDATE packaged_sources SET license='unclear'",
  "INSERT INTO packaged_sources SELECT 'extra',name,data_type,release,archive_url,archive_sha256,license FROM packaged_sources",
  "UPDATE packaged_products SET source_id='missing' WHERE fdc_id=1",
  "UPDATE packaged_products SET fdc_id=0 WHERE fdc_id=1",
  "UPDATE packaged_products SET fdc_id=1.5 WHERE fdc_id=1",
  "UPDATE packaged_products SET gtin14='00000000000018' WHERE fdc_id=1",
  "UPDATE packaged_products SET gtin14='00000000000000' WHERE fdc_id=1",
  "UPDATE packaged_products SET name='' WHERE fdc_id=1",
  "UPDATE packaged_products SET publication_date='' WHERE fdc_id=1",
  "UPDATE packaged_products SET publication_date='2026-02-29' WHERE fdc_id=1",
  "UPDATE packaged_products SET publication_date='2026-04-30T12:00:00Z' WHERE fdc_id=1",
  "UPDATE packaged_products SET modified_date='2026-13-01' WHERE fdc_id=1",
  "UPDATE packaged_products SET calories=-1 WHERE fdc_id=1",
  "UPDATE packaged_products SET calories=1000.1 WHERE basis_unit='g'",
  "UPDATE packaged_products SET calories=2000.1 WHERE basis_unit='mL'",
  "UPDATE packaged_products SET calories=1e999 WHERE fdc_id=1",
  "UPDATE packaged_products SET calories=NULL WHERE fdc_id=1",
  "UPDATE packaged_products SET protein_g=100.1 WHERE basis_unit='g'",
  "UPDATE packaged_products SET carbohydrate_g=200.1 WHERE basis_unit='mL'",
  "UPDATE packaged_products SET fat_g=-0.1 WHERE fdc_id=1",
  "UPDATE packaged_products SET basis_unit='oz' WHERE fdc_id=1",
  "UPDATE packaged_products SET basis_unit='ml' WHERE basis_unit='mL'",
  "UPDATE packaged_products SET serving_quantity=NULL WHERE fdc_id=1",
  "UPDATE packaged_products SET serving_quantity=0 WHERE fdc_id=1",
  "UPDATE packaged_products SET serving_quantity=10000.1 WHERE fdc_id=1",
  "UPDATE packaged_products SET serving_quantity=1e999 WHERE fdc_id=1",
  "UPDATE packaged_products SET serving_unit=NULL WHERE fdc_id=1",
  "UPDATE packaged_products SET serving_unit='mL' WHERE fdc_id=1",
  "UPDATE packaged_products SET serving_label='' WHERE fdc_id=1",
  "DELETE FROM packaged_products",
])
func packagedCatalogRejectsMalformedRowsSchemaAndProvenanceWithMatchingHash(_ mutation: String)
  throws
{
  let fixture = try packagedFixture()
  defer { try? FileManager.default.removeItem(at: fixture.directory) }
  try fixture.change(mutation)
  #expect(throws: PackagedFoodCatalogError.invalidData) { try fixture.open() }
}

@Test func packagedCatalogRejectsWrongHashesCorruptionMissingOversizedSymlinkAndSidecars() throws {
  let fixture = try packagedFixture()
  defer { try? FileManager.default.removeItem(at: fixture.directory) }
  #expect(throws: PackagedFoodCatalogError.invalidData) {
    try PackagedFoodCatalog(url: fixture.url, expectedSHA256: String(repeating: "0", count: 64))
  }
  #expect(throws: PackagedFoodCatalogError.invalidData) {
    try PackagedFoodCatalog(url: fixture.url, expectedSHA256: "invalid")
  }
  #expect(throws: PackagedFoodCatalogError.unavailable) {
    try PackagedFoodCatalog(
      url: fixture.directory.appendingPathComponent("missing.sqlite"), expectedSHA256: fixture.hash)
  }
  #expect(throws: PackagedFoodCatalogError.invalidData) {
    try PackagedFoodCatalog(
      url: URL(string: "https://example.invalid/database.sqlite")!, expectedSHA256: fixture.hash)
  }
  let link = fixture.directory.appendingPathComponent("link.sqlite")
  try FileManager.default.createSymbolicLink(at: link, withDestinationURL: fixture.url)
  #expect(throws: PackagedFoodCatalogError.invalidData) {
    try PackagedFoodCatalog(url: link, expectedSHA256: fixture.hash)
  }
  for suffix in ["-wal", "-shm", "-journal"] {
    let sidecar = URL(fileURLWithPath: fixture.url.path + suffix)
    try Data().write(to: sidecar)
    #expect(throws: PackagedFoodCatalogError.invalidData) { try fixture.open() }
    try FileManager.default.removeItem(at: sidecar)
  }
  try Data("not SQLite".utf8).write(to: fixture.url)
  #expect(throws: PackagedFoodCatalogError.invalidData) { try fixture.open() }
  let handle = try FileHandle(forWritingTo: fixture.url)
  try handle.truncate(atOffset: 40 * 1_024 * 1_024 + 1)
  try handle.close()
  #expect(throws: PackagedFoodCatalogError.invalidData) { try fixture.open() }
}

@Test func packagedCatalogRejectsOversizedRowCountAndBoundedText() throws {
  let fixture = try packagedFixture()
  defer { try? FileManager.default.removeItem(at: fixture.directory) }
  let excessive = String(repeating: "x", count: 301)
  let queue = try DatabaseQueue(path: fixture.url.path)
  try queue.write { db in
    try db.execute(
      sql: "UPDATE packaged_products SET serving_label=? WHERE fdc_id=1", arguments: [excessive])
  }
  #expect(throws: PackagedFoodCatalogError.invalidData) { try fixture.open() }
  let tooMany = try packagedFixture(count: 50_001)
  defer { try? FileManager.default.removeItem(at: tooMany.directory) }
  #expect(throws: PackagedFoodCatalogError.invalidData) { try tooMany.open() }
}

@Test func packagedCatalogErrorsNeverIncludePathsQueriesOrSQL() {
  for error in [PackagedFoodCatalogError.unavailable, .invalidData] {
    let message = error.localizedDescription
    #expect(!message.contains("/"))
    #expect(!message.contains("SELECT"))
    #expect(!message.contains("00000000000017"))
    #expect(message.contains("enter food manually"))
  }
}

/// Opt-in production smoke test; ordinary package tests use synthetic fixtures only.
@Test(.enabled(if: ProcessInfo.processInfo.environment["CALIBER_PACKAGED_CATALOG_PATH"] != nil))
func packagedCatalogFullDatasetMeasurementWhenSupplied() throws {
  let environment = ProcessInfo.processInfo.environment
  let path = try #require(environment["CALIBER_PACKAGED_CATALOG_PATH"])
  let hash = try #require(environment["CALIBER_PACKAGED_CATALOG_SHA256"])
  let start = ContinuousClock.now
  let catalog = try PackagedFoodCatalog(url: URL(fileURLWithPath: path), expectedSHA256: hash)
  let opened = ContinuousClock.now
  #expect(try catalog.foodCount > 1_000)
  // Only lookup well-formed synthetic GTINs here. A miss is expected and must be fast and safe.
  for index in 1...100 { _ = try catalog.product(gtin14: packagedGTIN(index)) }
  let end = ContinuousClock.now
  print(
    "PACKAGED CATALOG open+validation: \(start.duration(to: opened)); 100 lookups: \(opened.duration(to: end))"
  )
}
