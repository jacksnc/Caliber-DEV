# Hosted Foundation deployment — 2026-10-10

**DEV database and gateway deployed; positive hosted authentication and account isolation verified.** The owner approved the concrete permission and gateway changes with “you have my persmision,” then explicitly authorized creation of the two fictional test accounts with “you do it.” The atomic migration committed and the gateway's relay JWT setting was saved off. App activation remains disabled pending registration and provider safeguards; Step 2's activation gates and the broader Phase 1 acceptance are not claimed complete.

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
  verification/{preflight.sql,postflight.sql,owner_isolation.sql,http_smoke.py,auth_lifecycle.py}
  verification/tests/test_auth_runner.py
  tests/{deployment_test.ts,gateway_test.ts,rls_test.ts}
scripts/prepare_hosted.py
docs/HOSTED_DEPLOYMENT_VERIFICATION.md
docs/evidence/hosted-preparation/{format.log,lint.log,typecheck.log,tests.log,results.json}
docs/evidence/hosted-deployment/
```

Generated review files contain the complete deployable source: `index.ts`, `foundation.sql` and `deployment.json`. The approved editor copies matched these files exactly. After deployment, Select All/Copy from the published Code view also matched the reviewed gateway's 7,096 characters exactly (`source-match.json`). The generated manifest's `prepared_not_deployed` status is historical preparation metadata, not a live-state query. `docs/evidence/hosted-deployment/deployment-result.json` records the actual deployment and verification checkpoint separately.

## Destination and migration

Project: **Caliber DEV**, `tuvbdozxtkcxnojxbvlh`, `https://tuvbdozxtkcxnojxbvlh.supabase.co`, **us-east-1 / North Virginia**. The dashboard labels its main branch “PRODUCTION”; the owner selected this project as the development backend. Do not infer an additional staging branch.

Fresh dashboard observations on October 10: healthy project, no public tables/views, and “Deploy your first edge function.” The read-only SQL preflight returned `true` for both table names and both RPC names being available, both authentication roles existing, and `auth.uid()` existing. Required `auth.users` fields were `id` (no default), `is_sso_user` and `is_anonymous` (both have defaults). No user rows, keys, passwords, secrets or session tokens were read.

The applied atomic transaction created `caliber_accounts` and `caliber_revisions`, enabled row-level security, removed anonymous table privileges, allowed authenticated owner reads, and granted authenticated execution of `caliber_push` and `caliber_pull`. Those commands enforce `auth.uid()` ownership, validated operations, retry idempotency, atomic batches and causal conflict history. It contains no drop, existing-row update, local SwiftData conversion or personal-data upload. An object collision aborts the transaction; do not rerun the successfully applied migration.

The `caliber-gateway` bundle uses only Supabase's built-in URL and anonymous key on the server. It uses no service-role credential and embeds no credential. Its pre-login routes need `verify_jwt=false` at the relay. The endpoint is publicly reachable; Supabase Auth still validates sign-in/refresh/logout, and sync requires the caller's token plus database ownership checks. Disabling the relay check does not itself authorize sync. See the current [Supabase function authentication guidance](https://supabase.com/docs/guides/functions/auth).

Deployment review hashes:

| File | SHA-256 |
|---|---|
| index.ts | bfaa1d10f9ac01c8df4ba9cd8d67ff13bc6977ccfff0f0f5376b0d2a964c327a |
| foundation.sql | fc03f88827d33109f2cc6056ee8539c9ab05af7b0bf1b69c7813875f5b348ff7 |

## Verification report

| Criterion | Result | Evidence / remaining work |
|---|---|---|
| Existing destination and region confirmed | PASS | Signed-in project overview; no hosting account or project was created. Two ordinary fictional Auth users were created later for verification. |
| Hosted object-name and auth prerequisites | PASS | `backend/verification/preflight.sql`, one hosted metadata row, all six booleans true. |
| Backend format, lint and strict typecheck | PASS | Saved fresh `hosted-deployment` logs; Deno 2.9.7. |
| Local backend behavior | PASS — 12 Deno test functions | Nine gateway tests, owner-isolation/conflict PostgreSQL test and two deployment-verification tests. The new rollback script is run twice locally, checking that it leaves no fixture rows. |
| Auth verifier behavior/redaction | PASS — 3 Python fixture tests | A valid two-session scenario passes; global logout fails; an echoed password/token is absent from report and stdout. Hosted behavior is checked independently below. |
| Exact reviewed SQL/source deployed | PASS | Editor comparison before apply/deploy, then published gateway source comparison. Review hashes above are unchanged. |
| Hosted tables/RPCs and gateway deployed | PASS | SQL Editor returned “Success. No rows returned”; deployed settings view shows caliber-gateway and relay check off with Save disabled. The live HTTP checks prove handler execution. |
| Hosted grants/RLS/definer configuration | PASS — 6 criteria | `postflight.sql` returned true for every row; `catalog-ax.txt` and screenshot evidence. |
| Hosted owner isolation and atomic retry with simulated claims | PASS — 12 behavior assertions + 3 cleanup checks | `owner_isolation.sql` requires enabled assertions. Checks retry, paging, conflict leaves/historical merges, whole-batch rollback, collision rejection, own/cross-owner reads/writes, missing subject and anonymous execution. Hosted final cleanup row is true/true/true. No passwords, identities or sessions were created; every fixture row rolled back. Sequence gaps and approximate statistics may remain. |
| Hosted HTTP rejection paths | PASS — 11 requests | `http-smoke.json`: missing/forged tokens rejected; malformed/invalid/unknown requests denied; invalid refresh rejected. Every response matched its exact sanitized error and no-store header. No key or genuine credential was used. |
| Positive signed-token authentication and isolation | PASS — 18 criteria | `auth-lifecycle.json`: three genuine sessions, valid expiry/subject contract, authenticated push/pull/retry for both owners, cross-owner denial, current-session logout, revoked refresh rejection, survival of the other session and remaining-session logout. Reports exclude credentials/tokens. The first attempt stopped during the first sync request for an unclassified transport/response failure; its session cleanup passed. A full rerun passed without backend changes. Both sanitized reports are retained. |
| Provider protections and activation | FAIL / hardening remains open | Existing provider settings inspected without changing them: email enabled; anonymous sign-in off; email confirmation on; general signup on; CAPTCHA off; token limit 150/5min; signup/sign-in and verification limits 30/5min; IP forwarding off. See limitations below. `gatewayDeployed` remains false as the app's activation guard. |
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
cd ..
python3 -m unittest discover -s backend/verification/tests -v
python3 backend/verification/http_smoke.py --output /tmp/caliber-http-smoke.json
```

For future deployment verification, run `postflight.sql` in this project's SQL Editor and require all six rows to pass. `owner_isolation.sql` uses an explicit transaction and rollback, never permanent test-account credentials. Check signed-token authentication independently from simulated claims and catalog configuration. Save only fictional fixtures, public metadata and sanitized outcomes as evidence.

## Fictional credentials and positive test

The empty authentication store was confirmed with a read-only `NOT EXISTS` query before opening the account-creation form. The agent initially handed off credential creation under Chrome's loaded browser guideline. The owner's later explicit “you do it” authorized the agent to create the named fictional accounts. The owner's instruction takes precedence over that skill guideline.

Created `caliber.qa.a@caliber.invalid` and `caliber.qa.b@caliber.invalid` as ordinary confirmed users through **Authentication → Users → Add user → Create new user**, leaving **Auto confirm user?** checked. The form states that no confirmation email is sent. Each password was independently generated with 32 random bytes, held in a private mode-0600 temporary file outside the repository, and never printed or added to evidence. The file was removed after verification; no password or token is delivered to the owner. This is file removal, not a claim of storage or process-memory zeroization.

The two fictional accounts and one synthetic note per account remain in DEV for inspection. They have no elevated privileges. Future reruns require new privately chosen passwords via the owner's Auth dashboard; the discarded passwords cannot be recovered from these artifacts. No personal account was edited or deleted.

For a future rerun, use only these confirmed fictional accounts and run from the repository root. The runner asks for each password privately; keep passwords and tokens out of chat, command arguments, repository files and logs.

```sh
python3 backend/verification/auth_lifecycle.py --output docs/evidence/hosted-deployment/auth-lifecycle.json
```

The positive test writes one fictional note to each test account, using fixed fixture owner/operation IDs so retries are safe. These signed-token fixtures remain until their test accounts are explicitly cleaned up; they do not read or upload diary/photo data. The runner attempts current-session logout for every issued session, including after a failed check. It never logs raw response bodies or secrets. A failed cleanup remains a failed result. Existing access JWTs can remain valid until expiry; the test checks refresh revocation rather than promising instant access-token invalidation.

## Provider limitations and activation gates

The gateway exposes no signup route, but the project's general Supabase signup setting is currently on. Account registration policy still needs to be closed or implemented deliberately before app activation. CAPTCHA was already off; no protection was disabled to make tests pass. Do not turn off an existing CAPTCHA to run this harness. CAPTCHA integration/source eligibility, provider logging retention/redaction and account recovery/delete remain open release work.

Auth rate limits are configured, but the gateway uses an anonymous server key without end-user IP forwarding. [Supabase's current rate-limit documentation](https://supabase.com/docs/guides/auth/rate-limits) says forwarded IP handling requires a secret API key and explicit configuration; anonymous/publishable keys do not support it. Consequently these settings do not prove per-device abuse protection through this proxy, and shared gateway egress can share a rate-limit bucket. Do not increase limits or add privileged keys as a shortcut. A reviewed gateway abuse-control design remains an activation gate. The live checks requested us-east-1; no full residency or actual execution-region claim is made.

No calculation methods or charts changed in this step; their previous verification still applies. No production readiness, full Phase 1 completion or cloud activation is claimed.

Recommended next step: finish the registration policy and gateway abuse-control design, then verify the remaining provider safeguards before enabling the app's account connection. DEV deployment and positive backend auth verification are complete; activation, live domain sync and the broader Foundation acceptance remain open.
