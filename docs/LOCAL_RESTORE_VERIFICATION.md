# Local restore rehearsal — 2026-10-13

The saved legacy archive can now reconstruct all 15 current SwiftData model types in a separate in-memory container. The rehearsal compares the rebuilt model values, IDs, relationships and photo bytes to the saved snapshot. It never opens or replaces the app's live store. Email setup stays pending under the owner's latest instruction.

## Plan

1. Inspect the existing archive and all current model properties.
2. Rebuild current models from the saved snapshot in memory.
3. Preserve optional links, restaurant customizations and editable diary nutrition.
4. Reject incompatible fields, IDs, links, types and calculated snapshots.
5. Verify photos, ordering, original weight values and saved-meal relationships.
6. Inject a reconstruction failure and prove the source/archive remain unchanged.
7. Run app regression tests, strict formatting and diff review.
8. Keep canonical disk migration, encrypted backup and cloud activation separate.

## Complete files

```text
Caliber (DEV)/Services/LegacyRestoreRehearsal.swift
Caliber (DEV)Tests/LegacyRestoreTests.swift
Caliber (DEV)Tests/LegacySnapshotTests.swift
scripts/lint_foundation.py
docs/adr/009-local-restore-rehearsal.md
docs/evidence/local-restore/
```

The source archive contains complete files and the Xcode project. This is developer verification infrastructure, not a new user-facing backup button. No UI, catalog, calculation policy, API key, signing setting or app-store locator changes.

## Behavior

Only version-1 snapshots captured by LegacySnapshotAdapter are supported. Strict keys prevent an unrecognized future field from disappearing silently. Type checks distinguish booleans from numbers, require finite numeric values and preserve exact integers including Int.min/Int.max, validate enums/UUIDs, and reject malformed Base64. Declared references must match payload relationships and point to actual captured records.

Reconstruction creates all objects before wiring links, including cyclic inverse relationships. It preserves IDs and uses the original pounds instead of converting canonical kg back into rounded values. Canonical kg must agree with the existing exact factor 0.45359237. Food values remain independent of menu catalog values; quantity-derived diary totals must match their captured snapshots.

A second ModelContext reads the new memory container and recaptures supported model properties. Equality must include raw JSON payload bytes and reference lists. Unknown fields, incompatible units, mismatched totals or automatic repairs to inconsistent inverse links fail the rehearsal. No surviving partial disk copy is created. The helper accepts neither an existing context nor a file destination, and tears down only its own memory container.

The archive itself still supplies persisted/checksummed input through LegacyShadowArchive. The all-15-model test reopens that archive, reconstructs the graph and verifies both source and archive are unchanged. This does not prove a normalized GRDB conversion or an application restart against a restored disk store.

## Verification report

| Criterion | Result | Evidence / scope |
|---|---|---|
| All 15 existing types reconstruct from the saved/reopened archive | PASS | Extended legacyShadowCopy test; entity counts and exact rows match |
| Source context and stored archive remain unchanged | PASS | Before/after captures and reread of the original snapshot |
| IDs, inverse relationships, custom catalog values and diary adjustments are preserved | PASS | Full graph equality plus distinct custom menu/food calories and derived totals |
| Photo bytes, sort ties, linked/standalone weight and original pounds are preserved | PASS | Three-photo fixture includes 196,608 bytes; all rows/IDs/references match |
| Orphaned optional food/meal links and an empty snapshot remain valid | PASS | No invented food or other records |
| Invalid restoration fails without modifying the source or creating files | PASS | 13 variants: type confusion, fractional order, bad Base64, units/kg, enum, field, reference, duplicate/unknown row and totals |
| Inconsistent inverse links cannot silently become a different graph | PASS | Expected incompleteFixture and unchanged source |
| Injected failure allows retry and leaves unrelated files intact | PASS | Fail-after-two fixture, unchanged sentinel/source, subsequent success |
| App compiles and all selected unit regressions pass | PASS | 74 Swift Testing functions plus two template XCTest cases on iPhone 17 / iOS 27 |
| Strict Swift formatting and diff review | PASS | lint.log; changed source reread; git diff check |
| Disk cutover, canonical mapping, backup encryption and minimum iOS 17 runtime | FAIL — outside this checkpoint | Remain Foundation gates; no live migration or new encryption claim |
| Recovery email/cloud activation | FAIL — intentionally pending | Owner selected continued local work; app activation remains false |

The first build caught a missing try in a test assertion and was repaired. An initial disk-based rehearsal passed the tests but exposed SQLite open-file deletion diagnostics. Autorelease scoping and a teardown attempt did not fully resolve those diagnostics. The final implementation avoids creating a second disk-based SwiftData store and performs restore mapping in memory from the persisted archive. This changes the scope of durability evidence explicitly; it does not hide the failed cleanup experiment. The older Progress disk-fixture test can still log its pre-existing cleanup diagnostic during the full suite; no such diagnostic comes from the final restoration helper.

No new charts or health estimates are added, so chart image/performance budgets and calculation methods are unchanged. These tests cover fictional data only. No network, hosted database change, account creation/deletion or personal upload occurred in this checkpoint.

## Migration and reproduction

No schema migration or live cutover is needed. The existing SwiftData schema and its 15 model files remain unchanged. Rehearsal IDs are evidence IDs; original model UUIDs stay intact.

From the repository root:

```sh
python3 scripts/lint_foundation.py
xcodebuild test \
  -project 'Caliber (DEV).xcodeproj' -scheme 'Caliber (DEV)' \
  -destination 'platform=iOS Simulator,name=Caliber Account QA' \
  -parallel-testing-enabled NO \
  -test-timeouts-enabled YES \
  -default-test-execution-time-allowance 90 \
  -maximum-test-execution-time-allowance 120 \
  '-only-testing:Caliber (DEV)Tests' CODE_SIGNING_ALLOWED=NO
```

Select any available iOS simulator if the dedicated QA simulator is absent. In Xcode, open **Caliber (DEV).xcodeproj**, select **Caliber (DEV)** and an iPhone simulator, then choose **Product → Test** (**⌘U**). The new cases are under **LegacyRestoreTests**, and the all-model archive case is under **LegacySnapshotTests**. Press **⌘R** to run the app; its existing diary and Progress screens behave as before.

## Recommended next local step

Implement the normalized archive-to-GRDB projection into a separate target store, then reconcile diary totals, relationship ownership and photo references against this legacy rehearsal. Private attachment encryption and protected recovery must precede a real cutover or shareable backup. Email sender setup remains deferred until the owner resumes it.

SwiftData ownership and explicit memory/CloudKit configuration follow [Apple's ModelContainer documentation](https://developer.apple.com/documentation/swiftdata/modelcontainer) and [ModelConfiguration](https://developer.apple.com/documentation/swiftdata/modelconfiguration).
