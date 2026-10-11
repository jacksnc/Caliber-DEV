# ADR-007 — Shared pre-login budgets for private DEV

Date: 2026-10-11. Status: accepted for DEV; public-release safeguards remain open.

## Decision

Disable general Supabase signup, keep anonymous signup off and email confirmation on. Ordinary accounts are created deliberately in the owner's existing DEV dashboard. No signup, email invitation, recovery or administrative route is added to the gateway.

Use the existing Postgres instance for shared token buckets. Each eligible sign-in or refresh spends one global token and one keyed-identifier token atomically before calling Supabase Auth. Lock the global row first, then the identifier row, using the database clock. Client timestamps, process-local counters and caller-supplied IP headers cannot reset the limits.

| Route | Global burst capacity | Identifier burst capacity | Continuous refill |
|---|---|---|---|
| sign-in | 20 | 5 per normalized email | Each bucket recovers its capacity over 300 seconds |
| refresh | 50 | 10 per refresh-token fingerprint | Each bucket recovers its capacity over 300 seconds |

These are token buckets, not strict counts per fixed five-minute window: a full bucket permits an initial burst plus subsequent refill. Existing provider limits still apply and can reject requests sooner. A denied identifier does not spend a global token. An empty global bucket does not create another identifier row.

The gateway uses HMAC-SHA256 with a generated 256-bit server-only secret to derive identifiers, separating sign-in from refresh. Raw emails, passwords, refresh tokens and IP addresses are not stored in the guard tables. The secret is in Supabase's function-secret store; Postgres holds only its SHA-256 digest. The new RPC has no table/health-data privileges for its callers: anon execution additionally requires this guard. PUBLIC and authenticated execution are revoked; both tables have RLS, no client policies and no client table privileges. No service-role key or new external provider/account is needed.

Missing configuration, a failed guard request or malformed guard response prevents sign-in/refresh with a sanitized 503. Exhausted budgets return 429 plus bounded Retry-After. Provider 429 responses are also sanitized. Logout does not consume these pre-login budgets, so an exhausted login bucket cannot prevent the existing local-scope logout route. Existing journal ownership/RLS remains unchanged.

Read auth bodies incrementally with an 8,192-byte ceiling; retain the existing 9,000,000-byte sync ceiling. Unknown routes are rejected before reading a body. No credentials or health values are logged by this code.

## Limits of this decision

- These are shared gateway and identifier budgets, not verified per-device/IP controls or a WAF. An attacker rotating identifiers can exhaust the shared budget and affect availability. Guard requests still invoke the function/database; this is not infrastructure DDoS protection.
- A party holding a Supabase public/anon key can call Auth directly. The gateway budget does not replace provider protections or establish resistance to that path. Existing provider limits were not increased and no CAPTCHA was disabled. Public bot protection, CAPTCHA integration or an attestation/WAF design still needs a separate reviewed setup.
- Each route's successful traffic removes its buckets last updated over 24 hours ago. An idle route retains stale rows until its next successful request; this is not a strict wall-clock retention guarantee. Cleanup stays under the route lock already held, so sign-in and refresh cannot lock each other's stale rows. Forward migration 003 makes this explicit while preserving configuration/grants. A scheduled retention job and provider log/backup policies remain release work.
- Keyed identifiers remain pseudonymous security metadata, not anonymous data. The guard stores no personal health content. Provider logging/retention and full residency have not been certified by these tests.
- This additive server migration is independent of SwiftData. No existing health record, account or app-store locator is converted or erased. Cloud activation remains off until consent and account lifecycle safeguards are implemented and verified.

## Evidence

Twenty local backend tests cover guard refusal, sanitized errors, privacy, body limits, capacities, refill, clock regression, grants and rollback/ownership regressions. Hosted metadata checks pass; six simultaneous requests for one fictional nonexistent account forward five attempts and throttle the sixth. Case/whitespace/IP spoofing cannot reset the bucket. Eighteen genuine signed-token checks pass using two new ordinary fictional accounts. See `docs/AUTH_HARDENING_VERIFICATION.md`.
