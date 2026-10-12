# ADR-008 — Optional account access, recovery and self-deletion

Date: 2026-10-12. Status: accepted for DEV; email delivery and app activation pending.

## Decision

Keep the existing native app and local store. A separate, versioned `account-access-v1` permission precedes any account restoration, login or recovery. It discloses the email/authentication requests, Supabase processing and security metadata. It does not grant permission for personal health sync, photos, AI or analytics. Store the version/date locally; record authenticated acceptance server-side using `auth.uid()` and the server clock. Stopping services removes this device's permission and saved session, without deleting the hosted account. Historical acceptance remains until account deletion; this is not a universal consent system or legal approval.

The optional UI implements code-based recovery without deep links. The gateway accepts only an email for a request and email/code/new password for a reset. Responses do not disclose account existence. Recovery does not return or persist a session in the app. After password update, attempt global refresh-session revocation; if it fails, return an explicit uncertainty flag and clean the ephemeral session best-effort. Existing access JWTs can remain usable until expiry.

Keep the existing guarded Postgres budgets. Add separate recovery-request capacities of 10 global/2 per normalized email and recovery-verify capacities of 20 global/5 per email, refilling continuously over 300 seconds. Existing sign-in (20/5) and refresh (50/10) capacities, grants, secret and counters are preserved. Deletion's password check spends the existing sign-in budget. This does not establish public bot protection, per-device/IP limits or strict idle retention.

Self-deletion requires a verified current bearer, the current password and fixed DELETE confirmation. The server fetches the Auth user, reauthenticates that email and requires the same authenticated subject. The client cannot supply a target subject/email/owner. Only then call Supabase's supported Admin delete-user API. Existing cascading foreign keys remove that subject's journal and acceptance record. Report success only after a confirmed response; local logs/photos/weight/notes stay intact, and local credentials are cleared afterward. A Keychain-clear failure exposes a removal action and prevents restoration in the current gateway instance.

## Narrow administrative capability

This supersedes ADR-007's statement that no administrative route or service-role use exists. The function reads Supabase's built-in `SUPABASE_SERVICE_ROLE_KEY` from its protected environment solely for the reauthenticated self-delete request. It is neither copied nor embedded in app/source/artifacts. Login, refresh, recovery, consent and sync retain anonymous/user-scoped requests; health-journal RPCs retain JWT/RLS ownership checks.

This is a privileged server capability, not a database-enforced restriction on the service-role key itself. A compromised function/environment could have wider privileges; least-privilege deployment access and secret protection remain required. Do not extend this path into general account administration. Missing server configuration fails closed.

## Migration and limits

Forward migration 004 adds the acceptance table/RPC and recovery budget routes without changing the live SwiftData store or resetting counters. No automatic downgrade or real-user erasure is performed. The QA verifier is fixed to a disposable fictional account; no arbitrary deletion target is accepted.

The recovery HTML is prepared with `{{ .Token }}`, but the dashboard currently requires custom SMTP to edit the template. No email provider credentials were supplied, no paid account was created and no real email was sent. Hosted recovery delivery is unverified. The shipping app's activation flag remains off.

Auth deletion is not certified backup/log erasure. Provider retention needs a policy. Accounts owning Storage objects may be refused by Auth; cloud-photo upload is not enabled, and no broad storage purge is implemented. Future attachment sync must supply a tested ownership-specific deletion workflow before activation. Supported API behavior is documented by [Supabase user management](https://supabase.com/docs/guides/auth/managing-user-data); token templates are documented in [Supabase email templates](https://supabase.com/docs/guides/auth/auth-email-templates).

## Evidence

29 backend tests, 66 package test functions, 68 app test functions plus two template cases, six verifier tests and three isolated account UI tests pass. The hosted disposable lifecycle passes twelve criteria; read-only catalog checks verify actual Auth/journal/consent deletion and preservation of the four earlier QA accounts. Exact deployed source equality and relay state are recorded. See ACCOUNT_LIFECYCLE_VERIFICATION.md for current evidence and open acceptance.
