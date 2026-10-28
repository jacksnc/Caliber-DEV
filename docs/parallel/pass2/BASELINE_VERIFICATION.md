# Pass 2 common-base verification

2026-10-28, Xcode 27.1 / iPhone 17 simulator iOS 27.0, fictional test stores.

- Prior native polish `955a91b`: GitHub run 40639535461 completed all three jobs
  (`ios`, `backend`, `ui`) successfully, verified before creating this base.
- Shared merge includes Claude's scanner-mode and singular-exercise fixes through
  `c9413af`; no working branch was replaced.
- Native unit suite on the combined base: 10 XCTest + 215 Swift Testing cases pass.
- Scanner mode switching to label input: passes.
- Full AX5 walkthrough reached the scanner after the other screens; its scanner
  title reported repeated text clipping. The fixed-size trial title was replaced
  by a title that wraps vertically inside its actual HStack width. Mode labels
  keep Claude's whole-word layout and all route identifiers.
- New focused `testScannerLargestTextLayout` runs the scanner at AX5 and passes
  the existing repeated Dynamic Type/text-clipping audit. No issue was suppressed.
  This is a focused follow-up to the failed broad run, not a claim of a fresh
  complete device/accessibility certification.
- Foundation lint, static/document contracts and scratch-only schema checks pass.
- No new model, private-data migration, provider, flag or nutrition/dosing formula.

Local evidence: `/tmp/caliber-pass2-base.xcresult` (initial combined run),
`/tmp/caliber-pass2-scannerfix.xcresult` (focused fix). Physical camera/device and
minimum-iOS checks remain release work. Role owners must verify their own diffs.
