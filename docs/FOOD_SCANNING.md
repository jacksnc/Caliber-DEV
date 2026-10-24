# Food barcode scanning and label capture

How the scanner pipeline fits together, what each piece of `Packages/FoodCore` does, and what still has to be verified
on a real device. FoodCore is pure Swift with no UI and no networking of its own; the app supplies the camera, the HTTP
transport and the database.

> **Status.** The engines are covered by 142 XCTest cases that pass on Linux Swift 6.1 and 5.10.1 (the compiler in
> Xcode 15.4) and on the macOS CI runners (see `.github/workflows/ios-ci.yml`). Nothing here has been run against a
> real camera, real Open Food Facts or USDA responses, or real nutrition labels. Section 9 lists exactly what to check.

## 1. Pipeline

```
camera frames
   |  VisionKit DataScannerViewController (barcode + optional text)
   v
ScanStabilizer ........ 2 identical valid reads in 0.8 s (1 read for DataMatrix/QR), 2.5 s cooldown
   |
   v
BarcodeNormalizer ..... GS1 check digit, UPC-A/EAN-13/EAN-8/UPC-E/GTIN-14, GS1 element strings, Digital Link
   |                    -> [BarcodeCandidate]  (two when an 8-digit code is both a valid EAN-8 and UPC-E)
   v
FoodResolver (actor)
   1. not a food code?       -> .notAFoodBarcode(kind)        coupon, book, store label, drug ...
   2. user's own food?       -> .found (never cached)
   3. cache (TTL)            -> .found(fromCache) / .notFound / .unavailable
   4. providers in parallel  -> OpenFoodFactsProvider + USDAProvider (per-source timeout)
   5. FoodMerger             -> best record, gaps filled per nutrient basis, allergens unioned
   6. cache write            -> hit 30 d, miss 24 h (only if EVERY source answered), failure 2 min
   v
.found / .notFound / .unavailable / .notAFoodBarcode / .invalid
```

If the code is unknown, the user scans the Nutrition Facts panel instead:

```
photo of label -> VNRecognizeTextRequest -> [TextFragment] -> TextRowAssembler -> rows
   -> LabelParser (US panel, EU per-100 table) -> ParsedLabel (readings, confidence, warnings)
   -> confirmation screen (highlight ParsedLabel.needsConfirmation) -> FoodDraftBuilder -> FoodRecord(.labelScan)
```

## 2. Module map

| File | What it does |
| --- | --- |
| `GS1.swift` | Mod-10 check digit, UPC-E <-> UPC-A zero-suppression (all four patterns) |
| `GTIN.swift` | `GTIN` (canonical 14-digit), consumer-unit from case code, `BarcodeKind` by GS1 prefix |
| `BarcodeNormalizer.swift` | Scan -> candidates; typo suggestions for manual entry; `BarcodeSymbology` mapping from Vision identifiers |
| `GS1Elements.swift` | `(01)...(17)...(10)...` and raw FNC1 element strings, GS1 Digital Link, lot/expiry/net weight |
| `Serving.swift` | "2/3 cup (55g)", "1 1/2 tbsp", "8 fl oz (240 mL)", "6 x 330 ml" |
| `Nutrients.swift`, `FoodRecord.swift` | Canonical nutrients and units; `FoodRecord` with per-100 g, per-100 ml and per-serving bases; portion scaling |
| `OpenFoodFacts.swift`, `USDA.swift`, `JSONValue.swift` | Request builders and tolerant mappers (numbers as strings, g -> mg/mcg, kJ -> kcal, salt -> sodium, IU -> mcg) |
| `Quality.swift` | Consistency checks, 0-1 quality score, merge with provenance (`fieldSources`) |
| `AllergenDetector.swift` | Advisory allergen keywords from ingredient text |
| `LabelParser.swift`, `TextRowAssembler.swift` | OCR text -> readings, %DV cross-check and repair |
| `ScanStabilizer.swift` | Debounce, cooldown, retry/backoff and the offline pending queue |
| `FoodResolver.swift` | Cache protocol, providers, resolver actor |
| `FoodDraft.swift` | "Add this product" |

## 3. Barcode facts the code relies on

- **Check digit.** Weights 3,1,3,1... from the digit next to the check digit. Applies to GTIN-8/12/13/14 alike, which is
  why UPC-A, EAN-13 (leading zero) and GTIN-14 (two leading zeros) of one product all normalise to the same `GTIN`.
- **UPC-A on iPhone.** Apple's frameworks report UPC-A as an EAN-13 with a leading zero. The normaliser therefore never
  uses the symbology to tell them apart; a unit test covers the equivalence. *Verify on device.*
- **UPC-E vs EAN-8.** Both are 8 digits, and the check digits often coincide: exhaustive enumeration shows that 58% of
  valid UPC-E codes also pass the EAN-8 check (for the "five-digit manufacturer" zero-suppression pattern the weights
  are identical, so every such code is valid both ways), and about 12% of valid EAN-8 codes also pass the UPC-E rule.
  **Always pass the symbology from the scanner.** Without it, both readings are returned and the resolver tries them in
  order (`preferUPCE` flips it); `01234565` in the tests is a realistic UPC-E that is also a valid EAN-8.
- **What is not a product.** Prefix 2 (UPC) / 20-29 (EAN) is a retailer's random-weight label, 3 is an NDC drug code,
  4 is in-store, 5 and 98x/99x are coupons, 977 periodicals, 978/979 books. None of these is looked up; the resolver
  returns `.notAFoodBarcode(kind)` so the UI can say why.
- **Cases.** A GTIN-14 with indicator 1-8 is a case or inner pack. The resolver looks up the consumer unit
  (`gtin.consumerUnit`: drop the indicator, recompute the check digit) and the UI should say "case code scanned".
- **2D codes.** GS1 DataMatrix, GS1 QR and Digital Link carry a GTIN plus lot, dates and weights; `ScanInterpretation.gs1`
  exposes them (a future "track expiry" feature). Year pivot for 2-digit dates is the 50-years-back / 49-ahead window;
  confirm against the current GS1 General Specifications before relying on it for anything but shelf life.

## 4. Result states and what the UI should do

| `ResolveOutcome` | UI |
| --- | --- |
| `.found(record, fromCache, sources)` | Show the product with a portion picker (`FoodRecord.nutrients(for:)`). Show `record.flags` as a quiet "check these numbers" note, never as a block. Show `sources` in a details sheet. |
| `.found` with `record.allergens` | List as "Contains (from ingredient text / source tags)". Always add "Check the package." Absence of an allergen is never shown as safe. |
| `.notFound(answered)` | "We don't know this product yet." -> scan the label -> `FoodDraftBuilder`. |
| `.unavailable(errors)` | Offline or all sources down. Offer "Save for later": `PendingScanQueue.enqueue`; retry with `RetryPolicy` (30 s doubling to 6 h, 8 attempts). |
| `.notAFoodBarcode(kind)` | One-line explanation by kind (store label, coupon, book...) and a manual-search button. |
| `.invalid(.badCheckDigit(expected:suggestions:))` | Camera: "Couldn't read that clearly, hold steady." Manual entry: offer `suggestions` ("Did you mean ...?"). |

`FoodQuality.score` is 0-1 (source trust x completeness x consistency). It is a heuristic for choosing between sources,
not a statement of accuracy.

## 5. VisionKit integration (not compiled in CI)

This wrapper is a sketch against the public VisionKit API; it needs a physical device (the simulator has no camera) with
an A12 Bionic or later and iOS 16+. Add `NSCameraUsageDescription` to Info.plist.

```swift
import SwiftUI
import VisionKit
import FoodCore

struct BarcodeScannerView: UIViewControllerRepresentable {
    var onConfirmed: (StabilizedScan) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode()],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        if !scanner.isScanning { try? scanner.startScanning() }
    }

    func makeCoordinator() -> Coordinator { Coordinator(onConfirmed: onConfirmed) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private var stabilizer = ScanStabilizer()
        private let onConfirmed: (StabilizedScan) -> Void
        init(onConfirmed: @escaping (StabilizedScan) -> Void) { self.onConfirmed = onConfirmed }

        func dataScanner(_ s: DataScannerViewController, didAdd added: [RecognizedItem], allItems: [RecognizedItem]) { handle(added) }
        func dataScanner(_ s: DataScannerViewController, didUpdate updated: [RecognizedItem], allItems: [RecognizedItem]) { handle(updated) }

        private func handle(_ items: [RecognizedItem]) {
            for case let .barcode(barcode) in items {
                guard let payload = barcode.payloadStringValue else { continue }
                let symbology = BarcodeSymbology(identifier: barcode.observation.symbology.rawValue)
                let now = ProcessInfo.processInfo.systemUptime          // monotonic
                if case let .confirmed(scan) = stabilizer.ingest(payload: payload, symbology: symbology, at: now) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onConfirmed(scan)
                }
            }
        }
    }
}
```

Check `DataScannerViewController.isSupported` and `.isAvailable` before presenting, and fall back to manual entry
(`BarcodeNormalizer.normalize` accepts typed digits with spaces or hyphens). Honour Reduce Motion for the scan-line
animation and give a VoiceOver announcement on a confirmed scan.

### Label capture

```swift
let request = VNRecognizeTextRequest { request, _ in
    let observations = request.results as? [VNRecognizedTextObservation] ?? []
    let fragments = observations.compactMap { observation -> TextFragment? in
        guard let text = observation.topCandidates(1).first?.string else { return nil }
        let box = observation.boundingBox            // normalised, origin bottom-left
        return TextFragment(text: text, minX: box.minX, midY: box.midY, height: box.height)
    }
    let label = LabelParser.parse(lines: TextRowAssembler.rows(from: fragments))
    // show the confirmation screen; highlight label.needsConfirmation and label.warnings
}
request.recognitionLevel = .accurate
request.usesLanguageCorrection = false   // language correction "fixes" numbers into words
```

Take a still photo rather than parsing live video: dense small print needs the full-resolution frame. Tilted labels
break row assembly (rows drift past the tolerance); prompt the user to square up the panel.

## 6. How the label parser protects the diary

OCR mistakes the parser repairs, and only when the repaired number agrees with the printed %DV (current 2016 and
pre-2020 FDA reference values are both accepted):

| Printed | OCR reads | Repair |
| --- | --- | --- |
| `8g 10%` | `89 10%` | drop the trailing digit (a "g" read as 9, 8 or 6) |
| `4.5g 6%` | `45 6%` | restore the decimal point (gram nutrients only) |
| `160mg` | `160m9` | unit normalisation |
| `0g` / `0mg` | `Og` / `Omg` | letter O as zero |

Anything that cannot be reconciled is kept as read, marked `.low` confidence and reported as a
`percentDailyValueMismatch` warning; the confirmation screen must show those rows. Calories that disagree with
4P + 4C + 9F by more than 25% / 25 kcal raise `energyMismatch`. The parser never invents a missing value.

## 7. Data sources

| Source | Terms | Notes |
| --- | --- | --- |
| Open Food Facts | ODbL database, CC BY-SA images | Attribute in the app. Looking a product up and showing it is fine; copying records in bulk into a database you redistribute triggers share-alike. Send a descriptive `User-Agent` with a contact address. The documented read limit is about 100 product requests per minute (verify current terms). |
| USDA FoodData Central (Branded) | Public domain (CC0) | Needs an API key, rate limited (documented default 1,000/hour). Keep the key in an edge function and point `USDAProvider(baseURL:)` at it. |
| User-created foods | Yours | Always win over external data. |

`OpenFoodFacts.requestKeys` tries the 13-digit zero-padded key first and the short spelling second, because the exact
normalisation on their side could not be checked offline. `USDAFoodDataCentral.searchKeys` tries UPC-A, EAN-13 and
GTIN-14 spellings and only accepts a result whose `gtinUpc`, zero-padded to 14 digits, equals the scanned GTIN.

## 8. Privacy and safety

- What a person scans is health-adjacent data. Do not call third-party APIs straight from the device with any user
  identifier. Route lookups through the existing Supabase edge function so third parties see the function, not the user,
  and so API keys never ship in the app.
- Log nothing about barcodes in analytics. Offer an "offline only" switch that uses cache and user foods.
- Allergen output is advisory (`AllergenDetector` finds mentions in ingredient text; Open Food Facts tags are
  community data). The UI wording must be "may contain / check the package", never "safe".
- Flags and warnings never block logging; they ask the user to look twice.

## 9. Verify before trusting (checklist for the first device session)

1. UPC-A, EAN-13, EAN-8 and UPC-E packs report the symbology and payload you expect; confirm the leading-zero behaviour.
2. A real Open Food Facts response and a real USDA search response decode as the fixtures assume (field names, units,
   `serving_quantity` type, liquid products). Replace the synthetic fixtures with captured, de-identified samples.
3. USDA search by UPC returns the branded record in the first page for common US products; if not, add `gtinUpc:` query syntax.
4. `LabelParser` on 30+ real photos across brands: measure how many rows are right without repair, how many are repaired
   correctly, how many are flagged. The unit tests prove the logic, not the OCR quality.
5. Stabiliser feel: 2 reads in 0.8 s should confirm in well under a second on a steady hand; tune `ScanStabilizerConfig`.
6. Timeouts: `ResolverPolicy.providerTimeout` (6 s) on a slow cellular connection.

## 10. Tunable constants

| Constant | Default | Where |
| --- | --- | --- |
| Reads to confirm / window / cooldown | 2 / 0.8 s / 2.5 s | `ScanStabilizerConfig` |
| Positive / negative / failure cache TTL | 30 d / 24 h / 2 min | `ResolverPolicy` |
| Provider timeout | 6 s | `ResolverPolicy.providerTimeout` |
| Early-stop quality (sequential mode) | 0.7 | `ResolverPolicy.stopAtQuality` |
| Retry backoff | 30 s x 2, cap 6 h, 8 tries | `RetryPolicy` |
| Energy cross-check slack | 25% and 25 kcal | `NutritionValidator` |
| Source trust priors | user 1.0, USDA 0.9, label 0.85, OFF 0.75 | `FoodSource.trustPrior` |
| %DV tolerance | 1.5% of the Daily Value plus label rounding | `LabelParser.dailyValueTolerance` |
