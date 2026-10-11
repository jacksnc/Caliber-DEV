# DEV authentication safeguards — 2026-10-11

**Private DEV registration and gateway-budget checkpoint complete.** Public signup is disabled, the shared guard is deployed and genuine authentication is reverified. App cloud activation remains off while consent, account recovery/delete and provider release safeguards are completed. This does not complete Phase 1 or make a public-release claim.

## Plan

1. Verify the current provider configuration and preserve the previously verified gateway.
2. Close general signup without disabling confirmed-email access for existing users.
3. Implement shared Postgres budgets, keyed identifiers and bounded request reads.
4. Add a clear localized retry message to the app.
5. Run backend, Swift package and isolated app regression checks.
6. Deploy the new guard migrations/configuration and compare published source.
7. Verify hosted permissions, concurrent rejection, signed-token lifecycle and credential cleanup.

## Files

```text
backend/supabase/functions/caliber-gateway/
  auth_budget.ts
  handler.ts
  index.ts
backend/supabase/migrations/{002_auth_guard.sql,003_auth_guard_route_cleanup.sql}
backend/tests/auth_guard_test.ts
backend/tests/gateway_test.ts
backend/verification/
  auth_guard_preflight.sql
  auth_guard_postflight.sql
  auth_guard_smoke.py
  auth_lifecycle.py
scripts/{prepare_hosted.py,prepare_auth_guard.py}
Packages/CaliberFoundation/Sources/CaliberIntegrations/CloudGateway.swift
Packages/CaliberFoundation/Tests/CaliberIntegrationsTests/GatewayTests.swift
Caliber (DEV)/App/HostedAccountModel.swift
Caliber (DEV)/Resources/Localizable.xcstrings
Caliber (DEV)Tests/HostedAccountTests.swift
docs/adr/007-dev-auth-guard.md
docs/evidence/auth-hardening/
```

Complete source, migrations, tests and verification scripts are saved in the repository and the delivered source archive. There are no placeholder implementations on the added guard path. No calculation or chart method changed; prior chart evidence remains applicable.

## Migration and configuration

Destination: the owner's existing **Caliber DEV**, `tuvbdozxtkcxnojxbvlh`, configured **us-east-1**. Its main branch still carries the dashboard's “PRODUCTION” label; no additional staging branch is assumed.

Applied the transaction-wrapped **002_auth_guard.sql** after five read-only prerequisites passed. It adds two private RLS-protected security tables and one constrained definer RPC; it neither alters the Foundation journal nor migrates SwiftData. Its configuration initially denies pre-login requests. A private digest transaction enabled the guard, and the generated 256-bit secret was saved as `CALIBER_AUTH_GUARD_SECRET` in the server's function-secret store. The published 12,330-character gateway exactly matches the tested bundle. Relay JWT verification remains off for pre-login access; upstream JWT validation and database ownership remain enforced for sync/logout.

Final diff review found a possible lock cycle if two stale routes tried pruning each other's rows concurrently after a long idle period. Forward migration **003_auth_guard_route_cleanup.sql** scopes deletion to the route already locked, preserving its configuration/grants and changing no Auth/owner/limit contract. Backend tests were rerun with both migrations, verifying that each route cleans up only its own stale rows; the final hosted catalog and exact function-body comparison pass. The earlier genuine-auth and wire checks remain applicable because their contracts and gateway source did not change.

The native SQL warnings were reviewed: deletion statements are inside the guard's function and prune its stale security buckets. They do not delete existing accounts or health records. **Do not reapply migration 001, 002 or 003.** Rollback means redeploying an explicitly reviewed compatible gateway/configuration; dropping populated tables is not a production rollback procedure. No live user-store conversion occurred.

General signup is off, anonymous sign-in stays off, email confirmation stays on and email auth stays enabled. Supabase documents that disabling general signup still permits existing users to sign in. [General configuration](https://supabase.com/docs/guides/auth/general-configuration).

## Verification report

| Criterion | Result | Evidence |
|---|---|---|
| Registration restriction survives reload | PASS | `signup-policy-ax.txt` and reviewed screenshot: general/anonymous signup off, email confirmation on, Save disabled. |
| Guard prerequisites and migration | PASS — 5 booleans | `guard-preflight-ax.txt`; exact reviewed 4,700-character transaction committed with “Success. No rows returned.” |
| Guard table/RPC protections and final function | PASS — 5 criteria + exact body match | `guard-catalog-ax.txt` and `guard-function-match-ax.txt`: both tables private with RLS/no policies, fixed definer search path, anon-only guarded execution, configured/enabled, route-scoped cleanup and exact final body. |
| Original journal permission configuration | PASS — 6 criteria | Fresh `foundation-catalog-ax.txt`; original owner-read grants, policies and RPC restrictions are intact. |
| Published source and relay setting | PASS | `source-match.json` and `relay-settings-ax.txt`; exact bundle hash, legacy relay verification off, Save disabled. |
| Backend format/lint/strict typecheck | PASS | Saved fresh `format.log`, `lint.log`, `typecheck.log`. |
| Backend behavior | PASS — 20 test functions | `tests.log`: eight new guard tests plus twelve existing gateway/database/deployment tests. Covers quotas/refill/private grants, outages, input bounds and credential-safe errors. |
| Private-password verifier | PASS — 3 local tests | `verifier-tests.log`: successful local scope, rejected global logout and secret-echo redaction. |
| Swift package behavior | PASS — 60 test functions | Core 8, Database 14, SeedData 3, Integrations 26, Charts 9. New 429 test cannot persist a session. A fresh isolated package build/test passed; recorded in `local-results.json`. |
| iOS app build and unit behavior | PASS — 66 Swift Testing functions + 2 template XCTest cases | `ios-unit.log`: iPhone 17 / iOS 27; includes the new wait-message assertion. UI suites were not rerun because no layout changed. iOS17 runtime and physical-device gates remain open. |
| Strict Swift formatting | PASS | `swift-lint.log`; changed code follows the existing formatter. |
| Hosted concurrent/boundary behavior | PASS — 6 criteria | `concurrent-http.json`: auth byte ceiling, empty-field refusal, absent signup route, five admissions/one throttle from six concurrent requests, normalized/spoofed-header retry blocked, another identifier still admitted to Auth. Uses nonexistent `.invalid` accounts and wrong fictional passwords. |
| Hosted rejection regression | PASS — 11 requests | Fresh `http-smoke.json`: missing/forged tokens, malformed/unknown requests and invalid refresh; exact safe bodies and no-store. |
| Genuine authentication after deployment | PASS — 18 criteria | Fresh `auth-lifecycle.json`, fixture set `auth-guard`: sign-in, expiry/subject contract, owner-bound sync/retry, cross-owner denial, local logout, rejected revoked refresh, other-session refresh and remaining-session logout. |
| Credential cleanup and diff review | PASS | Exact generated secret/password scan found no match in deliverable source/evidence; temporary secret/password/digest files removed. Changed source reviewed for permissions, state and data handling; no personal health upload. |
| App activation and public-release safeguards | FAIL / remains open | `gatewayDeployed=false`. Consent, recovery/delete, direct-provider/bot protection, scheduled retention, provider log/backup policies and broader Foundation acceptance are not implemented or certified by this checkpoint. |

The first concurrent probe was accidentally run while the dashboard's deployment-confirmation dialog was still open. It reached the previous uncapped gateway and failed the new criteria; `concurrent-before-update.json` retains that outcome. After confirming the update, reloading its published code and checking exact source equality, the complete probe passed. The old gateway had not consumed the new guard's budgets, so this rerun did not reset or bypass an exhausted bucket.

## Fictional fixtures and secrets

Created two additional ordinary confirmed users, `caliber.qa.guard.a@caliber.invalid` and `caliber.qa.guard.b@caliber.invalid`, using auto-confirm and no invitation/confirmation email. Each holds one synthetic note in a distinct fixture owner. The earlier two Foundation QA accounts and notes remain unchanged. Four fictional accounts now remain in DEV; no real account was edited or deleted.

Generated passwords and the server guard were held in mode-0600 temporary files outside the repository, never printed, and removed after verification. The server secret remains in Supabase's protected secret store; guard tables retain only its digest, and no reusable secret is in the app, repository or delivered archive. Provider log retention is not certified. All issued test sessions were logged out. This does not claim immediate access-JWT invalidation, process-memory zeroization or disk erasure. Future QA reruns need new privately selected passwords; the discarded values are not recoverable from these artifacts.

## Run / verify

From the repository root:

```sh
python3 scripts/lint_foundation.py
swift test --package-path Packages/CaliberFoundation --scratch-path /tmp/caliber-auth-verify-swift
python3 -m unittest discover -s backend/verification/tests -v
python3 scripts/prepare_hosted.py --output /tmp/caliber-auth-review
cd backend
deno fmt --check
deno lint
deno task check
deno task test
cd ..
python3 backend/verification/http_smoke.py --output /tmp/caliber-http.json
python3 backend/verification/auth_guard_smoke.py --output /tmp/caliber-guard.json
python3 backend/verification/auth_lifecycle.py --fixture-set auth-guard --output /tmp/caliber-auth.json
```

The concurrency probe consumes its fictional identifier's bucket. Wait for full refill before rerunning it. Do not increase provider limits, disable CAPTCHA, erase buckets or use real credentials to make verification pass. Run `postflight.sql` and `auth_guard_postflight.sql` as read-only dashboard checks; every row must pass. `prepare_auth_guard.py` is for a new disabled setup, refuses credential-file overwrite, and must never point into the repository or be used as an unreviewed rotation procedure.

To inspect the app manually, open **Caliber (DEV).xcodeproj**, select **Caliber (DEV)** and an installed iPhone simulator, then press **⌘R**. **Settings → Account** remains unavailable while activation is off. The error message is verified with isolated unit fixtures; these checks do not sign the owner into an app account or start cloud backup.

## Remaining work

The guard is a database-backed gateway budget, not a per-device/IP limiter or WAF. Caller headers are deliberately ignored. Supabase's forwarded-IP feature requires a different server key/configuration; existing provider limits were not changed. [Rate-limit documentation](https://supabase.com/docs/guides/auth/rate-limits).

A holder of the project's public/anon key can call Auth directly, so the gateway budget does not replace provider bot protection. CAPTCHA/attestation/WAF integration remains a separate setup/review choice; no paid account or external API key was created. Each route's active traffic prunes its old pseudonymous counters, but idle-route retention and provider log/backup retention still need scheduled and verified policies. See ADR-007 for the limits and exact token-bucket behavior.

Recommended next step: implement explicit account consent and recovery/deletion, preserving local logging, then verify the remaining provider safeguards before enabling private DEV sign-in. Personal domain sync remains a separate opt-in delivery.
