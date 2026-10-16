# Security and privacy design

Phase 0 · 2026-10-07 · requirements for future implementation. No penetration test, encryption audit or production-backend review was executed. The current app must not be described as meeting these controls yet.

## Boundary and threat model

Treat diary data, weight, photos, notes, symptoms, protocols, labs, inferred health context and health-related usage as sensitive. Protect against lost/unlocked devices, accidental sharing, malformed imports, malicious API callers, compromised dependencies, prompt injection, support-tool leakage and cross-account access.

The native plan is SwiftUI with an independently testable pure Swift core. Stack must have an isolated, separately protected persistence boundary; GRDB/SQLite is a proposed implementation, not encryption by itself. A feature flag, separate table, biometric sheet or separate file alone is not cryptographic isolation. Reuse IDs/provenance contracts without duplicating unrestricted health data into generic logs/rollups.

## Controls and evidence

| Surface | Required design | Proof before release |
| --- | --- | --- |
| Local database and photos | Platform data protection; separately encrypted Stack store and attachments with keys protected by Keychain; explicit biometric/device-lock policy. Include SQLite WAL/SHM, SwiftData external storage, thumbnails, temporary imports and exports. | Locked-device/backup/file inspection; key-loss, biometric-change and recovery tests; authenticated access cannot be bypassed by deep link, widget or query. |
| Backups and migration | Explicit backup/CloudKit policy; encrypted recovery artifacts; versioned migration and restore verification. Do not enable automatic cloud sync for health data by convention. | Reconcile rows, media bytes, relationships and entered units after restore; inspect backup manifests. See Apple policy evidence in COMPLIANCE. |
| API/backend/sync | TLS with normal certificate validation; authenticated endpoints; per-user authorization/RLS on every exposed table, storage object, realtime channel and RPC. Server service keys never on device. | Two-account denial suite, guessed-ID/object-path tests, expired/revoked tokens, replay and cursor isolation. |
| Keys and dependencies | Keychain/Keystore for tokens, least privileges, environment-specific secrets, rotation/revocation; lockfiles, dependency/secret scans. | Built-binary and repository scans; prove no API/provider/service-role secret in app or fixtures. |
| AI boundary | Server gateway; approved typed tools only; minimum necessary payload and consent; EXIF stripping; no training/retention beyond verified provider contract/settings. | Traffic capture, provider/config review, schema failures, injection/red-team tests; refusal/manual fallback without data leakage. |
| Logs/analytics/crashes | Allowlist technical status codes; never record health values, entry text, images, prompt bodies, URLs with health values or raw identifiers. Disable health-screen replay, screenshots and view breadcrumbs that reveal sensitive context. | Seed unique canary values/photos into every field and prove absence from all outbound SDK payloads, local logs and crash reports. |
| OS surfaces | Discreet notification defaults; app-switcher cover; minimal widget/Watch/App Intent payloads; permissions requested only when needed. | Lock-screen, notification action, accessibility, extension and background-state tests; denied permissions still allow manual logging. |
| Import/export | Bound file/image size, type and decompression; validate schema/units; defend CSV formula injection; local preview/redaction before sharing; temporary-file expiry. | Malformed/oversized input tests, cancelled-share cleanup, explicit export confirmation and content/metadata inspection. |
| Deletion | Delete owned attachments/caches/rollups and revoke sharing; tombstones prevent resurrection. Document backup retention and any lawful exceptions. | End-to-end deletion across device/server/processors/restore; retained tombstones contain minimal non-health metadata. |
| Kill switches | Signed/versioned configuration, regional scope, conservative disabled default for unapproved features, build-time omission. | Offline/stale/failed config and tampering tests; disabling never silently destroys existing records or misrepresents a dose as taken. |

No ads, health-data sale, health-based marketing or model training. Optional AI, Health integration and sync need separate meaningful choices. A privacy switch must affect queued uploads and cached provider requests, not only the visible screen. Where data handling remains undecided, use synthetic fixtures and keep external processing disabled.

## Security standard mapping

The brief's “MASVS L1; L2 for Stack” describes an assurance goal. Current [OWASP MASVS](https://mas.owasp.org/MASVS/) separates controls from [MAS testing profiles](https://mas.owasp.org/Profiles/Using-MAS-Profiles/), including MAS-L1/L2 and privacy work; checked 2026-10-07. Pin the selected standard/profile/MASTG revisions and map every applicable storage, crypto, authentication, network, platform, code and privacy control to a test and evidence. Use stronger Stack assessment and independent review. Do not claim an OWASP certification or equate a passing scanner with a complete assessment.

## Durability without privacy regression

Confirmation means the local transaction committed; a queued cloud upload is separate. Fixed operation IDs make retries idempotent. Dose/critical edit history is minimal, access-controlled and subject to retention decisions. Conflicts are visible; never choose a dosing instruction from a conflict. Migration backup/rollback must not discard unrelated pending work or reintroduce deleted photos. Hashes and counts can check migration without logging health content.

## Incident-response note

Before launch, assign named incident commander, security contact, privacy/counsel contact and alternate; configure a monitored reporting channel. These are **TBD release blockers**.

1. Triage reports promptly; record discovery time, affected systems and minimum necessary evidence in a restricted incident record.
2. Contain: revoke credentials, stop affected transfers, disable vulnerable endpoints/features and preserve evidence. Do not destroy user data as a containment shortcut.
3. Determine scope and recipients with privacy/counsel. Evaluate FTC/HIPAA, jurisdictional and contractual duties against the actual event; do not wait for proof of malicious hacking.
4. Send accurate notices through approved channels within applicable deadlines. Use the [FTC guidance](https://www.ftc.gov/business-guidance/resources/complying-ftcs-health-breach-notification-rule-0) and counsel-approved playbook; a single generic deadline is insufficient for all regimes.
5. Repair, verify recovery and deletion behavior, document root cause and preventive tests, and review vendor access.

Run a tabletop covering accidental analytics disclosure, leaked credentials and cross-user storage access before real-user release. Store the dated report with [COMPLIANCE](COMPLIANCE.md) evidence; never place private incident data in a public repository.

## Foundation implementation evidence and limits

New diagnostics accept an enum event and UUID only. Cloud requests default off; configured requests use HTTPS, ephemeral sessions, no cookies/cache, no redirects and generic errors. Tokens use a ThisDeviceOnly/WhenUnlocked Keychain item. Supabase keys remain server-side. Authenticated subject/owner binding, immutable operations, finite bounded payloads, causal relationships and RLS/RPC ownership are tested locally. Delayed auth responses must not resurrect a signed-out session.

The edge function has JWT verification disabled only at its outer entry because sign-in/refresh precede JWT issuance. Sync routes require a bearer token and invoke Postgres RPCs using that user's token; RPCs require `auth.uid()`. No service-role credential is used. The approved DEV deployment passes hosted catalog, simulated-claim isolation/rollback, missing/forged-token HTTP checks and eighteen positive signed-token checks using two owner-authorized fictional accounts. Current-session logout rejects the revoked refresh token while another session remains refreshable; access JWTs can remain valid until expiry. All issued test sessions were logged out, and generated temporary passwords were discarded. Existing general signup/CAPTCHA and provider logging policies remain to be hardened or verified. Auth's current IP limits may share gateway egress buckets because anonymous keys do not support forwarded-IP rate limiting. App activation stays off until these gates pass; see HOSTED_DEPLOYMENT_VERIFICATION.md.

Legacy photos/logs remain in their existing SwiftData store. File protection and separate demo files do not constitute the proposed encrypted Stack/attachment vault. No real Stack capture, telemetry provider, analytics SDK, AI upload or production cloud service is enabled by this phase. This is not an OWASP certification or legal sign-off.

### DEV pre-login safeguards — 2026-10-11

General signup is now disabled. The gateway uses shared Postgres global/identifier token buckets before sign-in/refresh, with a generated internal server-only guard and HMAC identifiers. Guard tables have RLS and no client table policies/privileges. Anonymous RPC execution additionally requires the independent guard, whose digest alone is stored in Postgres. No service-role key is used. Missing/unreachable guards close pre-login calls; throttling returns bounded safe retry information; logout stays independent of those budgets. Auth body reads stop at 8,192 bytes. Twenty backend tests and hosted concurrent/genuine-auth regressions pass; see AUTH_HARDENING_VERIFICATION.md.

These budgets do not establish per-device/IP or infrastructure DDoS protection and do not prevent direct Auth calls by a public-key holder. Provider limits/CAPTCHA were not weakened. Each route's active traffic prunes its stale pseudonymous buckets under the route lock, avoiding cross-route lock cycles; strict idle-route retention, provider log/backup policies and public bot protection remain release work. No personal health upload occurred, and app activation remains off pending consent and account lifecycle safeguards. ADR-007 records these boundaries and the exact capacities/refill behavior.

### Optional account lifecycle — 2026-10-12 (current checkpoint)

Versioned optional account permission now precedes account requests, separately from personal cloud/AI/analytics permission. Authenticated acceptance uses a live Auth-subject check and server timestamp; the table has owner-only reads, no client writes and restricted fixed-path RPC execution. Stopping services removes this device's permission/session; historical server acceptance is retained until account deletion.

The earlier no-service-role statements describe the October 10–11 implementations. ADR-008 supersedes them narrowly: the built-in server environment key is used only for a password-reauthenticated deletion of the same verified Auth subject. It never enters the app, repository, reports or archives. This code restriction is not a reduced-privilege key; function/environment compromise could have broader impact. Consent, recovery and sync retain their user/anonymous scopes and existing journal RLS.

Recovery uses separate guarded budgets, same safe request responses for existing/absent emails and no app recovery session. Password updates attempt global refresh-session revocation, with an explicit uncertainty result and best-effort ephemeral cleanup. Access JWTs can outlive refresh revocation until expiry. Hosted deletion confirms Auth removal and cascades that subject's journal/acceptance; failures do not claim success. Local health data remains intact; failed Keychain clearing exposes a removal path. Provider logs/backups, idle counters and owned Storage objects have separate retention/deletion requirements.

29 backend test functions and a twelve-criterion disposable hosted lifecycle pass; read-only cleanup verifies actual Auth/journal/acceptance absence and preservation of four earlier QA accounts. UI tests use a separate store and DEBUG mock. No personal health upload, real-user deletion or provider email occurred. Sender setup/delivery, provider safeguards, minimum-OS/device evidence, encrypted vaults and domain sync remain open. App activation stays off. See ACCOUNT_LIFECYCLE_VERIFICATION.md; this is not public release, OWASP certification or legal sign-off.

### Local restore evidence — 2026-10-13

The legacy graph restore helper accepts snapshot values only and always creates a separate in-memory store with CloudKit disabled. Exact recapture checks original IDs, nutrition, relationships, photo bytes and entered units; unknown/inconsistent inputs fail without touching the source. Persisted input comes from the existing reopened/checksummed archive. This is not an encrypted/shareable backup, a hostile-file importer or proof of disk cutover. No new health copy, key, cloud operation or diagnostic health payload is added to the app's runtime flow. The owner explicitly deferred email setup. ADR-009 records the discarded disk-copy experiment and the remaining storage/restore gates.

## Barcode and copy-rehearsal boundary — 2026-10-14

Camera frames remain in AVFoundation; only a validated barcode can be returned to lookup. The default online provider is pending/off. Explicit future online barcode permission is distinct from account consent; withdrawal clears transient results and invalidates outstanding result generations. The optional adapter uses fixed HTTPS OFF hosts/fields, an ephemeral bounded no-redirect transport and sanitized errors. No account token, diary, photo or health record is passed to it. Connection metadata and the barcode are necessarily visible to a configured provider; this is disclosed before permission. No product history/cache is persisted by lookup. A saved personal copy records its source ID and portion.

The normalized mapper accepts a supplied local snapshot and a separate fixed rehearsal filename; it never opens live SwiftData internals or Stack/cloud. It excludes its target directory from backups and applies complete file protection on iOS. Original photo BLOBs are unchanged. Neither plain GRDB nor the target digest is encryption, biometric access control or protection against a malicious writer who can rewrite hashes. A private vault and protected import/restore remain release prerequisites.

## Local food shortcuts — 2026-10-14

Recent/frequent lists read existing local food logs, with no external transmission or new analytics service. Favorite preferences contain bounded FDC IDs or content hashes only; hashes are identity keys, not encryption/anonymization. Nutrition, diary notes and photos are not copied into preferences. Personal favorites retain a saved library source; removing a star never erases a log. Copy/repeat operations preserve existing records and create independent values, with targeted cleanup on failure. UserDefaults' normal device storage behavior is not a private vault or protected portable backup.

Fictional shortcut UI fixtures require DEBUG, a test runtime flag and an in-memory container. Normal launches never seed these records. No real provider calls, hosted changes or sensitive uploads accompany this feature. Barcode requests now check cancellation before starting as well as before publishing a result; the default provider remains disabled pending setup.

## Public food database boundary — 2026-10-14

The new catalog contains public USDA records only. Its importer downloads only when explicitly requested, verifies bounded pinned archives before parsing and never sends diary/account/photo data. App catalog search is fully offline. A manifest checksum plus SQLite/source/row/FTS validation rejects missing or mismatched resources; SHA256 is integrity checking, not encryption or a signature. App-bundle signing is a separate platform boundary. The GRDB connection is read-only with query_only enabled, creates no migration or sidecar, and uses parameter-bound bounded searches built from normalized tokens. One shared background load keeps the resource check off the UI thread.

Personal logs remain separate editable snapshots; only the existing serving description gains the selected measure text. Favorites retain bounded source/content keys. No hosted settings, provider consent, account activation or live barcode/restaurant ingestion changed. Full personal-store encryption, structured provenance, portable preferences and release/device gates remain open.

## Offline packaged lookup — 2026-10-15

The shipped collection contains public source products, not lookup history. Catalog queries stay on device and require no online consent. A local hit cannot invoke the optional network service. Local misses reach a configured remote provider only after the existing separate permission check; task/generation checks prevent canceled or withdrawn attempts from initiating fallback. Tests use independent counting services to prove the boundary and suppress late results. Online setup remains off.

The source reader verifies bounded file/hash/schema/GTIN/nutrient/basis/date integrity and opens read-only without sidecars. One shared background load keeps full validation off the UI thread. Hashes are integrity checks, not encryption or arbitrary-import authenticity. No personal model migration, account request, photo upload, contact creation or provider key is introduced.
