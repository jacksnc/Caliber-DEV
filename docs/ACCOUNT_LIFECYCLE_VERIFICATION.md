# Account lifecycle checkpoint — 2026-10-12

The account permission, recovery-code client/server flow and password-confirmed hosted deletion are implemented. Migration 004 and the exact tested gateway are deployed to the owner's existing Caliber DEV project, `tuvbdozxtkcxnojxbvlh`, us-east-1. Email delivery is pending; the app's account activation flag remains false. This checkpoint does not complete Phase 1 or grant release/legal clearance.

## Plan (completed except sender setup)

1. Gate account requests behind optional, versioned permission.
2. Add bounded recovery endpoints without returning a recovery session.
3. Add password-confirmed deletion of the authenticated subject.
4. Preserve local logging and recover from credential-clear failures.
5. Test Swift, backend, verifier and isolated account screens.
6. Apply additive DEV migration and compare deployed source.
7. Verify fictional self-deletion and unchanged earlier QA accounts.
8. Configure a sender and verify real recovery delivery before activation (pending).

## File tree / complete files

```text
Caliber (DEV)/App/{FoundationRuntime,HostedAccountModel}.swift
Caliber (DEV)/Views/Foundation/HostedAccountView.swift
Caliber (DEV)/Resources/Localizable.xcstrings
Caliber (DEV)Tests/HostedAccountTests.swift
Caliber (DEV)UITests/FoundationUITests.swift
Packages/CaliberFoundation/
  Sources/CaliberIntegrations/{AccountGateway,CloudGateway}.swift
  Tests/CaliberIntegrationsTests/AccountLifecycleTests.swift
backend/
  supabase/functions/caliber-gateway/{account_lifecycle,auth_budget,handler,index}.ts
  supabase/migrations/004_account_lifecycle.sql
  supabase/templates/recovery.html
  tests/account_lifecycle_test.ts
  verification/account_lifecycle_{preflight,postflight}.sql
  verification/account_lifecycle_smoke.py
  verification/tests/test_account_lifecycle_runner.py
scripts/prepare_hosted.py
docs/adr/008-account-lifecycle.md
docs/evidence/account-lifecycle/
```

The delivery source archive contains complete tracked files and the Xcode project. Historical migrations 001–003 are included for reproducibility, not reapplication. The review bundle contains the deployed source and transaction-wrapped migration 004. A complete changed-file manifest is in ACCOUNT_LIFECYCLE_FILES.txt.

## Migration and deployment

Read-only prerequisite check: five passing criteria. Additive migration 004 ran inside BEGIN/COMMIT and returned success. Postflight: six passing criteria for owner-only consent, private grants, constrained definer/RPC execution, Auth cascade, recovery routes and unchanged original journal foreign keys.

Reloaded published code exactly equals the 21,913-character generated tested-source bundle. SHA-256: `aff76f276b0ced70d7ef38215af92f62898e5e6cf7a5e17fda9656c731727b28`. The relay's legacy JWT gate remains off because pre-login routes issue sessions; authenticated routes still use verified Auth/user-scoped RPCs. No keys were copied from the dashboard.

Do not reapply migration 004 or earlier migrations in this project. No live SwiftData conversion, database downgrade, guard rotation or counter reset occurred. A rollback requires a reviewed compatible forward migration/deployment; dropping populated tables is not a recovery procedure.

## Verification report

| Acceptance criterion | Result | Evidence |
|---|---|---|
| No account restore/sign-in/recovery before permission | PASS | HostedAccountTests and fixture UI; isolated UserDefaults |
| Permission version/date and authenticated server ownership | PASS | Swift tests, account lifecycle SQL test, preflight/postflight |
| Permission must be checked again after hosted deletion | PASS | Final UI asserts toggle off and Continue disabled |
| Password/code requests expose no app API key or saved recovery session | PASS | AccountLifecycleTests and Deno recovery tests |
| Existing/absent email use the same safe recovery-request response | PASS | Provider-status fixtures; no-store/error sanitization tests |
| Bounded recovery attempts and inherited guarded login limits | PASS | SQL recovery burst and existing auth guard regression tests |
| Current bearer/password, exact target and fixed confirmation required for deletion | PASS | Backend rejection/matching-subject tests and live wrong-password/target probes |
| Failed or malformed deletion preserves local credentials; confirmed deletion handles Keychain failure | PASS | Package tests with 401/409/500, malformed replies and failed clear |
| Local progress note survives hosted deletion | PASS | Dedicated QA simulator UI test; no personal store used |
| Deployed gateway matches tested source; schema permissions remain private | PASS | source-match.json, six postflight rows, relay-ax.txt |
| Disposable Auth subject, journal owner/revisions and consent are absent afterward | PASS | Five read-only cleanup rows; four earlier QA accounts remain |
| Deleted account refresh/consent/pull/login no longer succeeds | PASS | Twelve live lifecycle criteria; actual Auth absence independently confirmed |
| Format, lint, typecheck and package/backend/app tests | PASS | Saved logs: 29 Deno functions, 66 package functions, 68 app functions + 2 template cases, 6 verifier cases |
| Account screens compile and pass on available simulator | PASS | iPhone 17/iOS 27: three final account UI tests |
| Recovery email/code delivery and actual hosted password reset | FAIL — pending | Dashboard requires custom SMTP; prepared HTML is not installed; no email was sent |
| Private DEV account activation | FAIL — pending | CloudDeployment.json intentionally retains gatewayDeployed=false pending sender/provider safeguards |
| Minimum iOS 17 runtime and physical-device budgets | FAIL — pending | Available runtime is iOS 27; compile target 17 is not execution proof |
| Full Phase 1, encrypted vault/domain sync/public release acceptance | FAIL — pending | Existing Foundation gates remain open; this change adds no charts or health estimates |

Logs/evidence are in `docs/evidence/account-lifecycle/`. The first simulator run stalled while the laptop slept and failed; it is not counted as a pass. The bounded retry passed all 68 app functions, two template cases and three UI cases. Final view review moved status messages above the form and reset the consent toggle; the affected three UI cases were rerun successfully. Earlier unit/package/backend suites were not repeated after this view-only change.

## Fixtures and confidentiality

Created one ordinary auto-confirmed fictional account, `caliber.qa.lifecycle.20261012@caliber.invalid`, without sending confirmation/invitation email. The live verifier uploaded only one synthetic note, checked rejection paths, deleted its own authenticated account and attempted session cleanup. This destructive test intentionally cannot target an arbitrary account. The four earlier QA accounts were preserved. Provider logs/backups and pseudonymous auth-budget rows follow separate retention policies; they are not certified erased.

A generated password was held in a restricted temporary file outside the repository and discarded after verification. Reports contain criterion booleans and a fictional subject UUID, never response tokens/passwords. No real logs, photos, weight or Stack data were uploaded. This is not a claim of disk erasure or process-memory zeroization.

## Run / verify

From the repository root, with Deno installed (this environment used the existing bundled Deno 2.9.7):

```sh
python3 scripts/lint_foundation.py
swift test --package-path Packages/CaliberFoundation --scratch-path /tmp/caliber-account-swift
python3 -m unittest discover -s backend/verification/tests -v
python3 scripts/prepare_hosted.py --output /tmp/caliber-account-review
cd backend
deno fmt --check
deno lint
deno task check
deno task test
cd ..
python3 backend/verification/http_smoke.py --output /tmp/caliber-account-http.json
```

The self-deletion verifier needs a newly created disposable account matching its fixed email and a privately entered password; its previous account is deleted. Run only deliberately: `python3 backend/verification/account_lifecycle_smoke.py --output /tmp/caliber-account-live.json`. Never point it at a real account, weaken provider limits or clear security buckets to obtain passing tests. Read-only cleanup.sql refers to the already deleted fixture and is safe to rerun; prerequisite SQL for migration 004 is expected to fail once that migration exists.

For Xcode: open **Caliber (DEV).xcodeproj**, select **Caliber (DEV)**, select an installed iPhone simulator, and press **⌘R**. Normal **Settings → Account** still says setup pending. To run the isolated verification, select **Product → Test** (**⌘U**) for the account unit tests or the three named FoundationUITests. The UI suite's `--account-ui-testing` path uses a DEBUG-only mock account and separate local data; it makes no live auth requests.

## Recommended next step

Use an existing email provider, enter its credentials privately into **Supabase → Authentication → Emails → SMTP Settings**, then install recovery.html under **Templates → Reset password**. The dashboard currently prevents editing until SMTP is configured. [Supabase template documentation](https://supabase.com/docs/guides/auth/auth-email-templates) documents the one-time token placeholder.

Verify delivery, code expiry/reuse rejection, password change, old-password rejection and session revocation on a controlled non-health account. Finish provider bot/retention/logging safeguards before flipping the private DEV app flag. Public registration remains closed and personal domain sync requires its own consent and tested adapters.
