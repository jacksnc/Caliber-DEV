# Foundation readiness verification — 2026-10-10

**Step 1 is complete.** Scope: local readiness fixes and regression checks. Hosted deployment is the next step; Phase 1 as a whole remains open. Current source files are complete in the repository; the October 8 Phase 1 archive is a historical checkpoint.

## Verification report

| Criterion | Result | Evidence / practical scope |
|---|---|---|
| Foundation package compiles and tests pass | PASS — 59 test functions | [Package log](evidence/foundation-readiness/swift-test.log): Core 8, Database 14, SeedData 3, Integrations 25, Charts 9. Parameterized arguments are not counted as additional functions. |
| App builds and selected regression suites pass | PASS — 65 Swift Testing functions + 2 template XCTest cases + 7 UI tests | [Simulator regression log](evidence/foundation-readiness/ios-regression.log): all app unit suites plus 5 Foundation and 2 Progress fixture UI tests. The final method-heading adjustment is rebuilt and rechecked in the two demo-route tests separately. |
| Largest-text chart, table and method routes work | PASS — final 2 demo-route tests | [Final chart log](evidence/foundation-readiness/ios-chart-final.log): normal-size demo/table/exit and Accessibility XXXL on iPhone 17 / iOS 27. Audits cover Dynamic Type, clipped text and hit regions without issue filters. Table/info labels have at least 48pt touch regions. Demo exit works from the method route. These are reruns of two of the seven UI tests, not additional test functions. |
| Account restoration can recover from a failed check | PASS | App tests verify retry without restart, offline saved-session removal and no restoration/sign-in request while deployment is pending. The protocol is Sendable in CaliberIntegrations; its UI model remains on the main actor. |
| Existing decimal and Progress behavior is preserved | PASS | Unit tests cover both decimal separators, invalid/grouped/partial values and finite-value round trips. UI tests cover selected German formatting, Save/Cancel, daily check-in edit/delete, notes-only entry and number hiding. |
| Backend strict typecheck, format, lint and fixtures | PASS — 10 test functions | [Backend log](evidence/foundation-readiness/backend.log): 9 gateway tests and 1 PostgreSQL/PGlite integration test, including owner isolation, causal conflicts, retry/idempotency, rollback and paging. These are local fixtures, not hosted verification. |
| Static contracts and disposable SQL migrations | PASS — 43 SQL tests | [Contract log](evidence/foundation-readiness/contracts.log): schema reproduction, ownership and integrity contracts, semantic contrast tokens, feature flags, calculation fixtures and architecture links. No live migration. |
| Strict Swift formatting and diff review | PASS | [Strict lint log](evidence/foundation-readiness/lint.log) is empty on success. Foundation scope and changed root navigation; older app files are not cosmetically rewritten. Re-read changed source for state, decimal precision and credential/data handling; `git diff --check` passes. |
| Source-only deployment preparation | PASS | Generated handler/entry bundle, transaction-wrapped SQL and SHA-256 manifest. The script makes no network request and deploys nothing. |
| Hosted activation | FAIL / outside step 1 | `gatewayDeployed` remains false. No hosted SQL/function write, account creation or health upload occurred in this step. |
| Entire Phase 1 quality/release gate | FAIL / remains open | Minimum-OS execution, full VoiceOver/Dynamic Type audit, image baselines, physical-device budgets, coverage, hosted CI/auth/RLS, live domain sync and privacy lifecycle remain required. |

## Layout fixes and evidence

The original Dynamic Type audit identified Exit Demo in the native navigation toolbar. Giving that toolbar label a body font still failed. The final implementation uses a full-width bottom control with wrapping body text and at least 48pt height, available while scrolling or navigating into chart details.

The expanded audit then exposed clipped data-table text. Rows and explicit date headers now request their full wrapped height. Method paragraphs do the same. Visual inspection also caught a long navigation title that the audit did not flag: the short title is now “Method,” and “How we calculate” is a wrapping heading inside the page.

Final screenshots were visually reviewed: [normal-size chart](evidence/foundation-readiness/demo-standard.png), [largest-text chart](evidence/foundation-readiness/demo-AX5.png), [data table](evidence/foundation-readiness/table-AX5.png) and [method](evidence/foundation-readiness/method-AX5.png).

Captured screens use fictional demo data only. Passing automated audits establish the tested visible surfaces on this simulator; they do not replace a complete manual VoiceOver audit or guarantee every device, appearance, metric and localization. Screenshots are review evidence, not an automated golden-image comparison. The regression run passed before the final method-title adjustment; the final two demo-route tests rebuilt and verified that last adjustment.

Saved text logs normalize trailing whitespace and show carriage returns as literal `\r`; raw logs and result bundles remain in the temporary verification directory on this Mac. No test outcomes or failure messages are filtered.

The historical [Phase 1 report](PHASE_1_VERIFICATION.md) retains its original counts. Follow-through source and reproduction commands are listed in [Foundation readiness](FOUNDATION_READINESS.md).

## Migrations and run commands

No new schema version or user-store conversion is needed. Existing SwiftData logs remain in their original store. GRDB/SQL checks use disposable or fictional stores. Supabase configuration is public metadata only, with activation disabled.

Run from the repository root; use a fresh output directory for each simulator run:

```sh
python3 scripts/verify_phase1.py
python3 scripts/lint_foundation.py
swift test --package-path Packages/CaliberFoundation --scratch-path /tmp/caliber-readiness-swift
python3 scripts/test_ios.py --output /tmp/caliber-readiness-ios
python3 scripts/prepare_hosted.py --output /tmp/caliber-hosted-review
cd backend
deno fmt --check
deno lint
deno task check
deno task test
```

Local environment: Xcode 27.0 (27A266a), iPhone 17 simulator, iOS 27.0 (24A434), Deno 2.9.7. Compilation targets iOS 17, but iOS 17 runtime verification is still open because that runtime was unavailable from this installed Xcode. No overall or branch-coverage percentage is claimed. Older restaurant UI scripts remain excluded until their launches use isolated stores; their underlying edit/snapshot calculation logic is covered by unit tests.

To run manually, open **Caliber (DEV).xcodeproj**, choose **Caliber (DEV)** and an installed iPhone simulator in Xcode's top toolbar, then press **⌘R**. Open **Today → Explore a Year of Demo Data** to inspect charts, then their table/info links. Use **Exit Demo** at the bottom to return to your app. **Settings → Account** shows pending hosted setup.

Recommended next step: deploy the prepared gateway and owner-isolated journal to the selected development Supabase project, verify hosted auth and RLS with fictional accounts, then implement and verify live-log sync separately.
