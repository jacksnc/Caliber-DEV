# ADR-006 — Foundation implementation and activation boundary

Accepted engineering defaults, 2026-10-08. Native iOS/Android deferral was accepted by the owner's “Go” after Phase 0.

## Decision

Use one local Swift package with six products/targets: Core, Database, DesignSystem, Charts, SeedData and Integrations. This preserves module boundaries with one dependency resolver. GRDB.swift 7.9.0 is exact-pinned. Core stays UI/database independent; the application composes SwiftData and package services. Keep the Xcode project format at 77 (its previously declared preferred version) for the CI toolchain, and compile with iOS 17 deployment availability checks.

Retain working SwiftData flows. A separate fictional store exercises the canonical SQL, and a lossless snapshot archive exercises copying supported SwiftData values. Neither is a production cutover. Normalized repository adapters and a reversible user-store migration remain required before live sync.

Use a small immutable revision journal for the first end-to-end local sync protocol. The server stores account ownership and operations, validates parentage and exact-integer boundaries, and exposes RLS-protected push/pull RPCs. It does not accept arbitrary writes to canonical health tables. Payloads are bounded JSON objects; domain-specific validation must be added with each actual domain adapter. All conflict branches remain durable, including newer branches unknown to an earlier resolver. The common-ancestor projection may be absent when no unique safe value exists.

Keep cloud off in the application until a Supabase project, hosting region, consent and account lifecycle are configured and validated. The asynchronous owner question remains unanswered. No credentials, project, deployment, paid account, remote or upload was created. Keychain/session and gateway tests use synthetic values. Local sign-out clears the local session; upstream token revocation is an explicit remaining task.

Use PGlite 0.3.14 only as a development test dependency to run PostgreSQL RLS/RPC assertions. This is substantially stronger than a mocked SQL result, but it does not prove hosted auth configuration, server concurrency, region pinning, encrypted backups or operational recovery.

Seed only fictional observations. The simulation track uses arbitrary units, without a compound or actionable dose. Separate SQLite files are not advertised as encrypted Stack storage. English is the first interface language; string catalogs and locale formatting establish the localization boundary without claiming translated flows.

## Preservation and Git history

The pre-Phase-1 application was staged/untracked on top of the architecture commit. Reconstruct it from the saved staged/unstaged patches and existing file hashes, verify all baseline SHA-256 values, then commit `chore: checkpoint existing nutrition and progress app` before the Foundation changes. This produces a reproducible review base and avoids folding owner work silently into the Foundation diff. Original patches remain in the local work directory; application file contents were not reset.

## Consequences

This delivery can be reviewed and tested locally. Phase 1 is not declared complete while hosted CI/auth/sync, minimum-OS execution, coverage/image baselines and physical-device budgets remain unproven. Android is deferred by the accepted Phase-0 amendment, not marked tested. Stack security/legal/release gates stay open.
