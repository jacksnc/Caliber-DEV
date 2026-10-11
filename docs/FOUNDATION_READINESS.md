# Foundation follow-through — 2026-10-08

Status: local improvements implemented; October 10 verification is recorded in [Foundation readiness verification](FOUNDATION_READINESS_VERIFICATION.md). Hosted activation is prepared and pending. This does not close every Phase 1 acceptance gate.

## Plan

1. Inspect the owner's selected Supabase project and region without reading credentials.
2. Prepare public deployment metadata, a gated account screen and project-scoped Keychain sessions.
3. Verify session restore, offline sign-out and concurrent login/refresh/logout behavior.
4. Correct decimal input across food, restaurant and Progress forms.
5. Verify large-text chart controls and accessible data tables.
6. Prepare an atomic SQL migration and the exact tested gateway source for deployment review.
7. Keep cloud health upload and existing-store conversion unavailable until their own validation and consent gates pass.

## Selected backend

The owner's dashboard link selects **Caliber DEV**, project reference `tuvbdozxtkcxnojxbvlh`. The authenticated project overview shows `https://tuvbdozxtkcxnojxbvlh.supabase.co`, healthy status and **East US (North Virginia), `us-east-1`**. The public schema visualizer shows no tables; the Functions page shows “Deploy your first edge function.” Observed 2026-10-08; these observations do not assert that other schemas or authentication accounts are empty.

No dashboard credential, API key, personal health record or password was copied into the repository, tests or chat. `CloudDeployment.json` contains public metadata and `gatewayDeployed:false`; production account operations remain unavailable until deployment is verified. The debug account UI test substitutes a memory-only fictional gateway. It cannot contact Supabase.

Client requests select `us-east-1` through `x-region`, as described by [Supabase's regional invocation guide](https://supabase.com/docs/guides/functions/regional-invocation). This is a routing request, not proof of full infrastructure, telemetry or backup residency. Provider configuration and a hosted execution check remain required before a residency claim.

## Files

Complete current files are in this repository. The earlier Phase 1 archive is a historical checkpoint and does not contain these later changes. The main follow-through files are:

```text
Caliber (DEV)/App/HostedAccountModel.swift
Caliber (DEV)/App/FoundationRuntime.swift
Caliber (DEV)/Resources/CloudDeployment.json
Caliber (DEV)/Views/Foundation/HostedAccountView.swift
Caliber (DEV)/Views/Foundation/FoundationSettingsView.swift
Caliber (DEV)/Views/Foundation/TodayFoundationView.swift
Caliber (DEV)/Views/RootTabView.swift
Caliber (DEV)/Utilities/NutritionInput.swift
Caliber (DEV)/Views/Diary/
Caliber (DEV)/Views/Restaurants/
Caliber (DEV)/Views/Progress/ProgressEntryForm.swift
Caliber (DEV)Tests/HostedAccountTests.swift
Caliber (DEV)Tests/NutritionInputTests.swift
Caliber (DEV)UITests/FoundationUITests.swift
Packages/CaliberFoundation/Sources/CaliberIntegrations/HostedProject.swift
Packages/CaliberFoundation/Sources/CaliberIntegrations/AccountGateway.swift
Packages/CaliberFoundation/Sources/CaliberIntegrations/CloudGateway.swift
Packages/CaliberFoundation/Tests/CaliberIntegrationsTests/
Packages/CaliberFoundation/Sources/CaliberCore/FoundationSettings.swift
Packages/CaliberFoundation/Sources/CaliberCharts/ChartCard.swift
Packages/CaliberFoundation/Sources/CaliberDesignSystem/
backend/supabase/functions/caliber-gateway/handler.ts
backend/tests/gateway_test.ts
scripts/prepare_hosted.py
scripts/lint_foundation.py
```

## Account behavior

Settings → Account explains pending setup. After verified activation, an existing Caliber account can sign in. The dashboard account is separate. Passwords are cleared from the form when submitted or dismissed; only session tokens enter a Keychain item specific to this project, with device-only accessibility. Account operations never call a diary or photo synchronization adapter.

Saved sessions can be restored, and expired access tokens refreshed. A failed restoration can be retried or its saved session removed. Concurrent account actions are serialized. A stale login/refresh cannot resurrect a signed-out session. On sign-out the old session is captured and local storage cleared in order, before attempting remote revocation. Failure to reach the server is reported honestly as local-only sign-out. A newer login cannot be cleared or revoked by completion of an older logout.

The gateway fixes Supabase logout scope to `local` and rejects sessionless tokens to avoid the provider's legacy global-logout fallback. Supabase validates the token; decoding the session claim is only a shape check. See [Supabase sign-out](https://supabase.com/docs/guides/auth/signout) and [its logout implementation](https://github.com/supabase/auth/blob/master/internal/api/logout.go). Existing access JWTs can remain valid until expiration even after server logout; no claim of instant invalidation is made.

## Formatting and accessibility

Food quantities, calorie/macro overrides, custom restaurant items and Progress weight now use the format chosen in Settings. Opening an existing draft reformats its decimal separator once without rounding its value. Group separators, partial parses, nonfinite numbers and scientific-notation input are rejected. A full decimal expansion retains finite values when Swift would normally display scientific notation.

Settings no longer nests a second navigation stack when opened from the number-free journal. UI tests use their own preference store, including the original Progress unit preference. Chart table and method links put their minimum touch area inside the actual label, identify the metric to VoiceOver, and let text wrap. Chart height scales with text size. Data-table observations announce their date with the value; missing dates remain missing. The full-width Exit Demo control sits at the bottom across chart routes so its body text can grow with Dynamic Type.

## Migration and deployment proposal

No local data migration or hosted write was performed. The existing SwiftData store remains in use. Running `scripts/prepare_hosted.py` generates three review files without networking:

- `index.ts`: concatenates the tested handler and entry point; no external import, credential or copied boilerplate.
- `foundation.sql`: wraps the existing migration in `BEGIN`/`COMMIT`, so a collision or error rolls back the whole deployment. It adds `caliber_accounts`, `caliber_revisions`, owner-only read policies and authenticated `caliber_push`/`caliber_pull` commands. It does not drop or rewrite existing tables.
- `deployment.json`: destination, auth behavior, object names and SHA-256 hashes.

The function's pre-authentication routes must be reachable without a session. The proposed relay setting is `verify_jwt=false`; the handler forwards sign-in to Supabase Auth, and sync/logout retain authenticated checks downstream. No service-role key is used. See [Supabase function authentication](https://supabase.com/docs/guides/functions/auth). Activation must also verify provider rate limits, disabled-by-default signup flows, logging redaction and CAPTCHA requirements; CAPTCHA must never be disabled to make sign-in succeed.

## Run and verify

Open **Caliber (DEV).xcodeproj**, choose **Caliber (DEV)** and an installed iPhone simulator in the toolbar, then press **⌘R**. Open **Settings → Account** to see the selected backend's pending state. Your existing logging screens remain usable.

From the project folder:

```sh
python3 scripts/verify_phase1.py
python3 scripts/lint_foundation.py
swift test --package-path Packages/CaliberFoundation --scratch-path /tmp/caliber-foundation-swift
python3 scripts/test_ios.py --output /tmp/caliber-foundation-readiness-ios
python3 scripts/prepare_hosted.py --output /tmp/caliber-hosted-review
cd backend
deno fmt --check
deno lint
deno task check
deno task test
```

Use a new simulator result directory for every run. Verification results and outstanding acceptance gates are recorded in [Foundation readiness verification](FOUNDATION_READINESS_VERIFICATION.md).

Recommended next step: approve and deploy the reviewed gateway and owner-isolated journal to this development project, verify hosted authentication/RLS with fictional accounts and two clients, then complete domain adapters and the remaining Foundation gates before Train core.
