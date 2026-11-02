# Beta checklist execution — November 2, 2026

Owner authorized following the release checklist and using Claude/Gemini at
Codex's discretion. Coordinator: `codex/release-readiness` in
`/Users/jcrock/Documents/Codex/Caliber-release-readiness`.

## Ownership and actual dispatch

- Codex reviews/integrates pending QA changes, runs native checks, packages the
  approved Home Screen icon, and prepares signing/device evidence.
- Claude Opus 5.5 was prompted in the existing Caliber native chat for a bounded
  read-only review of FoodEntryPass2UITests, FoodShortcutsUITests,
  XCUIApplication+PrimaryNavigation, and the original QA verification note.
  The same one-time QA folder access previously approved by the owner was
  granted; Claude visibly read the four files. No edits or simulator jobs assigned.
- Gemini 3.8 Flash High was prompted in the existing native Mac chat to inspect
  the two approved aura logo files, provenance, the icon catalog and release
  handoff claims. It visibly inspected the files and checked the earlier
  archive evidence. No edits, simulator jobs, paid usage changes or personal
  browser access assigned.

The original integrated QA checkout has 19 modified files. Codex inspected its
five production-view changes and eight test-file changes, then exported only
those 13 Swift-file differences as `/tmp/caliber-beta-pending-qa-20261102.patch`.
The patch applied cleanly to this release branch. Original files and status
remain intact. Original QA documents are evidence rather than silently merged
over the release handoff. No schema/health/source-nutrition formula changed.

Reviewed production changes: consistent Diary date-picker time zone, standard
USDA food ordering before packaged results, account recovery message placement,
fresh goal-setup presentation identity, and Progress bottom scroll clearance.
Test changes preserve food amounts, source-energy, save/cancel, privacy,
independent diary snapshot, and layout assertions while correcting navigation,
keyboard, lazy-row and scroll discovery.

## Current verification

- Foundation lint passes; strict Dynamic Type lint: 242 files, zero findings.
- First focused native run completed on Compact QA only:
  `/tmp/caliber-beta-focused-20261102.xcresult`, log with the same stem `.log`.
  DerivedData `/tmp/caliber-beta-regression-derived`.
  Targets are the three outstanding FoodEntryPass2 workspace/meal-switcher/
  quick-review tests. Serial execution; per-test default 420 s, maximum 600 s.
  All 3 pass: theme/AX5 workspace 381.875 s, meal-switcher/reference 87.550 s,
  quick-review/cancel/edit/independent diary snapshot 135.856 s. This passing
  reproduction did not justify speculative helper or production changes from
  the peer review. The unresolved full-suite/order sensitivity remains open.
  Two exported Frost AX5 screenshots (manual and quick review) were visually
  inspected; scroll content remains distinct from visible bottom actions.
- The follow-up run `/tmp/caliber-beta-regression-20261102.xcresult` completed
  **277/277 passed, none skipped**: 260 app tests (244 Swift Testing + 16 XCTest)
  and 17 UI cases, including both timeout cases and relevant
  Profile, Progress, goal setup, account and search/barcode paths. Log has the
  same stem `.log`. Together with the first run, 20 distinct focused UI cases
  pass. This does not turn the historical broad 82/91 result green.
- The new runner completed a real `--unit-only` invocation in
  `/tmp/caliber-beta-runner-validation-20261102/Checks.xcresult`: 260/260 pass,
  none skipped. It created its own fresh iPhone simulator, then deleted it.
  Existing simulators were not shut down or deleted. Xcode had already shut
  down that temporary device; the cleanup's harmless already-shutdown message
  is preserved in the log and is suppressed in the current runner.
- The read-only archive checker tests pass 8/8; the runner guards pass 6/6.
  Summaries: `docs/evidence/release-beta/test-results.json`. The focused runs
  still contain 3 and 8 unattributed invalid-frame warnings respectively;
  no source cause was established or suppressed.
- Approved logo originals found under
  `/Users/jcrock/Documents/Codex/Caliber-logo-explorations-2026-11-01/approved-aura-variants/`.
  Both are opaque 1254-square PNGs. Exact proportional 1024-square downsampling
  is prepared outside the checkout in `/tmp/caliber-approved-icons-20261102/`;
  no redesign or crop. Gold-on-black is installed for normal/dark icons. Xcode's
  simulator build contains primary app-icon metadata for both iPhone and iPad.
  Hardware re-archive succeeds at `/tmp/caliber-beta-20261102.xcarchive`, log
  `/tmp/caliber-beta-archive-20261102.log`. All 10 compile-only packaging checks
  pass, including both executables, icon, root manifest, and widget identity/
  version. Hardware-generated iPhone/iPad icon metadata is present; the 120px
  phone icon was converted from Apple's optimized PNG and visually inspected.
  Provenance: `design/branding/app-icon.md`.
- `xcrun devicectl list devices` currently lists only simulated devices; physical
  iPhone evidence cannot yet be produced. Apple membership status asked through
  an asynchronous owner question; owner confirms **active personal membership**.
  Mac unlock and USB-connected/unlocked iPhone requested for the next signing
  stage. Keychain identity enumeration reports zero valid code-signing identities. Only an
  iOS 27 simulator runtime is installed; minimum-iOS execution remains open.

Independent reviews completed; findings and adopted/deferred decisions are in
`PEER_REVIEW.md`. Both native model tasks are idle. A further Gemini warning
audit could not be sent after the Mac locked; no such review is claimed.

CI previously selected only nine UI suites. All 24 reviewed fixture suites now
appear once across four independent shards, balanced from historical duration
evidence (~25–26 minutes each with individual stalled cases capped at 420 s).
Xcode's two nonasserting, persistent-store template cases remain explicitly
excluded. A source-coverage test rejects newly unclassified suites. Native
runner invocations create and clean up only their own disposable simulators.
Unit tests remain a separate CI job. Four unique result artifacts prevent name
collisions. The existing trusted screenshot publication is moved to its own
conditional writer job; UI jobs have read-only repository permissions. The
gallery represents shard 1; all four result artifacts retain complete evidence.
The additional unsigned hardware archive job uses explicit bash pipefail so
tee cannot mask a failed archive or checker. Ruby's YAML parser validates the
workflow; cloud jobs have not yet run.

All Python script tests pass: **149/149**, including the six runner guards and
eight archive checks. The lint-test fixtures deliberately emit lint errors to
verify rejection; the overall unittest run is OK. Foundation lint, strict
Dynamic Type (242 files, zero findings), and diff checks pass. Packaging reports
are `docs/evidence/release-beta/{archive-check,distribution-check}.json`.
The default distribution inspection fails only missing app/extension signing
material, as expected for the unsigned build. Team/provision/certificate
validation and App Store validation are still required, not inferred from a
successful archive or metadata check.

The historical full suite remains 82/91; no green full-suite or distribution
claim. No personal simulator, local-preview checkout, store, provider or account
configuration changed. Signing, upload and physical-device checks remain open.
