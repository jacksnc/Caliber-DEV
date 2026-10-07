# ADR-004 — Optional AI identification, deterministic quantities

Status: proposed; no API key or provider account required now.

Keep existing AIScanner service protocol and mock until a server gateway is authorized. Swift client calls a typed, authenticated backend; gateway adapters wrap provider-specific APIs. AI payload contains candidate food descriptors/grams/confidence or parsed user-entered fields, never trusted final nutrition. Database identity + serving conversion + pure math yield macros; restaurant hints narrow catalog matches. Unknown items stay unresolved and require a manual choice. Every critical entry is a draft until the user confirms.

The response contract includes request ID, schema/model/prompt versions, candidates, portion range, units and provenance. Reject unknown fields, non-finite/negative amounts, invalid enums and oversized payloads; rate-limit per account. Keys and provider routing are server-only. The mobile app remains fully useful with the feature off or network absent. Structured suggestions cannot call arbitrary tools/SQL or modify records.

Images are downscaled and metadata stripped before opt-in transmission. Do not send Stack data/photos to food AI. Consent specifies actual destination, retention and intended use; don't promise zero retention before a provider contract supports it. No health values in logs/crash context. Deletion covers caches and provider-side retention as contractually supported.

Pre/post policy checks plus deterministic intent routing block doses, titration, stacking, sourcing, diagnosis and extreme-diet recommendations. Rules govern any narration and query-tool access. Chat may explain the user's confirmed logs, not infer a treatment change. The user sees database-derived values and can edit them.

Phase 5 gates: ≥200 licensed/consented meals with documented ground truth; median/P90 kcal and protein absolute percentage error (zero-denominator cases separately reported); immutable splits/versioned evaluation; ≥100 red-team prompts; no final macro values sourced from the model; regression run on provider/model/prompt changes. Until these pass, AI flags remain off.
