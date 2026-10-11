# Changelog

## 2026-10-07 — Phase 0 architecture
- Audited the existing native app against the master brief, retaining its working food, restaurant and Progress flows.
- Proposed native Swift packages, explicit SQLite/GRDB repositories, separate private Stack storage and a conflict-preserving sync protocol.
- Added complete local SQL v1 proposals, disposable migration tests, ERDs, requirements/acceptance mapping, design tokens and registries.
- Added safety, licensing, security, calculation-method and verification documentation; open approvals remain explicit.
- No runtime app change, live database migration, third-party dataset import, cloud deployment or store submission.

Existing source work predates this phase and remains locally staged/uncommitted as it was. The phase commit includes architecture artifacts only.

## 2026-10-08 — Phase 1 local Foundation (activation gates open)

- Preserved and checkpointed the existing nutrition/restaurant/Progress application.
- Added six Swift package targets, pinned GRDB, separate demo databases and migration fixtures.
- Added Today, settings, adult/scope confirmation, number-free photo/notes journal and a 12-month fictional demo.
- Added accessible chart cards with calendar ranges, coverage, gaps, data tables and transparent descriptive math.
- Added lossless SwiftData snapshot rehearsal, immutable conflict-preserving sync journal, Keychain gateway client and PostgreSQL RLS/RPC tests.
- Added CI configuration and verification scripts. No hosted service or live data migration activated.
- Phase 1 remains open; see PHASE_1_VERIFICATION.md rather than treating this entry as release clearance.


## 2026-10-08 — Foundation follow-through, hosted activation prepared

- Selected and inspected the owner's existing Caliber DEV Supabase project in us-east-1; no hosted deployment or personal upload performed.
- Added gated account UI, project-scoped session configuration, restoration/retry and local-first current-session logout.
- Fixed locale-aware decimal input across existing nutrition, restaurant and Progress forms.
- Improved chart link touch regions, wrapping, VoiceOver labels and date-aware data tables.
- Isolated legacy Progress preferences in fixture UI runs and removed nested Settings navigation.
- Added deployment preparation and verification documentation. Phase 1 acceptance remains open.

## 2026-10-10 — Local readiness and largest-text fixes

- Replaced the demo's constrained navigation-toolbar exit with a persistent full-width bottom control.
- Let data-table date headers, values and method paragraphs wrap at accessibility text sizes; moved the full method heading into page content.
- Moved the Sendable account transport protocol into CaliberIntegrations and corrected failed session restoration so it can be retried without restarting.
- Expanded the largest-text UI test to audit chart, table and explanation routes and exit from the explanation page, without suppressing audit issues.
- Recorded current verification evidence separately from the historical Phase 1 baseline. Hosted activation, live synchronization and the remaining Phase 1 quality gates remain open.
