# Hosted Foundation deployment — 2026-10-10

**Prepared and staged; not deployed.** Step 2 remains open. The owner selected the existing Supabase project and requested this step. Browser confirmation is required immediately before changing cloud permissions and gateway authentication settings.

## Plan

1. Confirm project, region and object-name availability without selecting personal records.
2. Stage the exact tested SQL transaction and gateway bundle.
3. Confirm the concrete permission/authentication changes at deployment time.
4. Apply SQL, deploy the gateway and verify its relay setting.
5. Run hosted catalog, owner-isolation and HTTP/auth checks with fictional fixtures.
6. Keep app activation off until hosted authentication and provider safeguards pass.

## Files

```text
backend/
  supabase/functions/caliber-gateway/{handler.ts,index.ts}
  supabase/migrations/001_foundation.sql
  verification/{preflight.sql,postflight.sql}
  tests/{deployment_test.ts,gateway_test.ts,rls_test.ts}
scripts/prepare_hosted.py
docs/HOSTED_DEPLOYMENT_VERIFICATION.md
docs/evidence/hosted-preparation/{format.log,lint.log,typecheck.log,tests.log,results.json}
```

Generated review files contain the complete deployable source: `index.ts`, `foundation.sql` and `deployment.json`. They are not stubs. The browser editor copies were compared with these files through editor Select All/Copy: both matched exactly. No SQL migration was run and Deploy was not pressed.

## Destination and migration

Project: **Caliber DEV**, `tuvbdozxtkcxnojxbvlh`, `https://tuvbdozxtkcxnojxbvlh.supabase.co`, **us-east-1 / North Virginia**. The dashboard labels its main branch “PRODUCTION”; the owner selected this project as the development backend. Do not infer an additional staging branch.

Fresh dashboard observations on October 10: healthy project, no public tables/views, and “Deploy your first edge function.” The read-only SQL preflight returned `true` for both table names and both RPC names being available, both authentication roles existing, and `auth.uid()` existing. Required `auth.users` fields were `id` (no default), `is_sso_user` and `is_anonymous` (both have defaults). No user rows, keys, passwords, secrets or session tokens were read.

The proposed atomic transaction creates `caliber_accounts` and `caliber_revisions`, enables row-level security, removes anonymous table privileges, allows authenticated owner reads, and grants authenticated execution of `caliber_push` and `caliber_pull`. Those commands enforce `auth.uid()` ownership, validated operations, retry idempotency, atomic batches and causal conflict history. It contains no drop, existing-row update, local SwiftData conversion or personal-data upload. An object collision aborts the transaction; do not rerun a successfully applied migration.

The `caliber-gateway` bundle uses only Supabase's built-in URL and anonymous key on the server. It uses no service-role credential and embeds no credential. Its pre-login routes need `verify_jwt=false` at the relay. The endpoint will be publicly reachable; Supabase Auth still validates sign-in/refresh/logout, and sync requires the caller's token plus database ownership checks. Disabling the relay check does not itself authorize sync. See the current [Supabase function authentication guidance](https://supabase.com/docs/guides/functions/auth).

Deployment review hashes:

| File | SHA-256 |
|---|---|
| index.ts | bfaa1d10f9ac01c8df4ba9cd8d67ff13bc6977ccfff0f0f5376b0d2a964c327a |
| foundation.sql | fc03f88827d33109f2cc6056ee8539c9ab05af7b0bf1b69c7813875f5b348ff7 |

## Verification report

| Criterion | Result | Evidence / remaining work |
|---|---|---|
| Existing destination and region confirmed | PASS | Signed-in project overview; no account was created. |
| Hosted object-name and auth prerequisites | PASS | `backend/verification/preflight.sql`, one hosted metadata row, all six booleans true. |
| Backend format, lint and strict typecheck | PASS | Saved `hosted-preparation` logs; Deno 2.9.7. |
| Local backend behavior | PASS — 11 test functions | Nine gateway tests, owner-isolation/conflict PostgreSQL fixture test and deployment-catalog regression test. These do not establish hosted authentication. |
| Exact reviewed SQL/source staged | PASS | Editor clipboard comparison: gateway 7,096 characters; migration 9,093 characters. No deploy action. |
| Hosted tables/RPCs and gateway deployed | FAIL / pending confirmation | Browser draft only. |
| Hosted grants/RLS/definer configuration | FAIL / pending deployment | `postflight.sql` checks six criteria; its local test proves it detects disabled RLS and PUBLIC execution. |
| Hosted owner isolation and atomic retry | FAIL / pending deployment | Use fictional subjects and a rolled-back SQL fixture transaction. Simulated claims cannot establish signed-token authentication. Sequence gaps may remain after rolled-back inserts. |
| HTTP rejection paths and real auth lifecycle | FAIL / pending deployment/test accounts | Verify no-token/forged-token rejection and sanitized responses, then positive sign-in/refresh/current-session logout using fictional accounts and two sessions. Keep credentials out of evidence. |
| Provider protections and activation | FAIL / pending hosted checks | Inspect rate limits, signup exposure, logging and CAPTCHA requirements; never weaken CAPTCHA to pass a test. `gatewayDeployed` remains false. |
| Live domain sync and Phase 1 completion | FAIL / separate remaining gates | Existing domain logs are not uploaded; consent, domain adapters, lifecycle/delete and other Foundation gates remain open. |

## Run / verify

From the repository root:

```sh
python3 scripts/prepare_hosted.py --output /tmp/caliber-hosted-review
git diff --check
cd backend
deno fmt --check
deno lint
deno task check
deno task test
```

For hosted verification after confirmed deployment, run `postflight.sql` in this project's SQL Editor and require all six rows to pass. Check authentication behavior independently from catalog configuration. Save only fictional fixtures, public metadata and sanitized outcomes as evidence. A successful local test or dashboard “deployed” message is not hosted end-to-end proof.

No calculation methods or charts changed in this step; their previous verification still applies. No production readiness, full Phase 1 completion or cloud activation is claimed.

Recommended next step: confirm the staged deployment, apply it, then perform the hosted checks above before enabling the app's account connection.
