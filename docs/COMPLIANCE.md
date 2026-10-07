# Release review and policy evidence

Phase 0 draft · reviewed 2026-10-07 · no product certification or legal/clinical approval. A checked source means its text was inspected, not that Caliber satisfies it. No release checklist item is complete yet. Counsel, a qualified clinician and the owner must review the actual build, data flows, markets and marketing claims.

## Verified primary policy sources

| Source, checked 2026-10-07 | Verified requirement | Consequence / unresolved decision |
| --- | --- | --- |
| [Apple §1.4, Physical Harm](https://developer.apple.com/app-store/review/guidelines/#physical-harm) | Medical accuracy claims require supporting methodology. §1.4.2 limits drug dosage calculators to specified medical entities or regulatory approval. | STK-06 is a release blocker pending eligibility/policy/legal review. A “math only” disclaimer does not establish an exception. Build-time omission is the fallback. |
| [Apple §5.1.3, Health and Health Research](https://developer.apple.com/app-store/review/guidelines/#health-and-health-research) | Health-data use is restricted; §5.1.3(ii) prohibits storing personal health information in iCloud and inaccurate HealthKit writes. | Explicitly review CloudKit, backups and exports; do not enable automatic health-data cloud storage. |
| [Google Health Content and Services](https://support.google.com/googleplay/android-developer/answer/16679511?hl=en&rd=1) | Health declaration, public privacy policy and appropriate disclosure are required. Harmful medical functionality and promotion/sale of unapproved substances are prohibited. Medical-device and other health-app requirements differ. | Android is a later platform. Review Stack content, claims, declaration and listing before that release; disclaimers do not authorize prohibited functionality. |
| [Google Health Connect permissions](https://support.google.com/googleplay/android-developer/answer/16558241?hl=en#health-connect) | Approved user-facing use, minimum permissions, transparent handling and limited uses/transfers are required; advertising and data-broker uses are prohibited. | Establish permission-by-feature matrix and consent/revocation tests before integration. |

Apple and Google acceptance cannot be promised from this desk review. Re-read the full current policies before every submission. Regional flags may disable functionality; they must not conceal functionality from reviewers. A kill switch is a containment tool, not proof of compliance or a dependable emergency medical service.

## Legal questions requiring counsel

These primary sources were checked on 2026-10-07. Applicability and implementation remain **unresolved**; this is a review agenda, not legal advice.

| Jurisdiction / source | Review required before collecting real user data in scope |
| --- | --- |
| EU: [GDPR, Articles 6 and 9](https://eur-lex.europa.eu/eli/reg/2016/679/oj/eng) | Identify lawful basis and applicable special-category condition, controller/processors, DPIA need, transfers, withdrawal, access/erasure and retention. Explicit consent is not a universal answer to every processing purpose. |
| UK: [ICO special-category guidance](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/lawful-basis/special-category-data/what-is-special-category-data/) | Review UK law separately; health inferences can also be sensitive. Confirm current UK requirements rather than treating EU analysis as sufficient. |
| California: [Attorney General CCPA guidance](https://oag.ca.gov/privacy/ccpa) | Determine applicability and current thresholds/exemptions; map health information, access/correction/deletion, notice, and use/disclosure restrictions. No ads or sale is a product commitment, not a blanket exemption. |
| Washington: [AG My Health My Data guidance](https://www.atg.wa.gov/protecting-washingtonians-personal-health-data-and-privacy) | Assess consumer-health data, separate consents, privacy notice, deletion propagation and processors. Do not assume small size or out-of-state location removes obligations. |
| US: [FTC Health Breach Notification Rule guidance](https://www.ftc.gov/business-guidance/resources/complying-ftcs-health-breach-notification-rule-0) | Assess PHR/vendor/service-provider status and breach duties; unauthorized disclosure can matter even without a malicious intrusion. Incident procedures need counsel-approved recipients and deadlines. |
| US: [HHS health-app developer resources](https://www.hhs.gov/hipaa/for-professionals/special-topics/health-apps/index.html) | Determine HIPAA covered-entity/business-associate relationships from actual contracts and integrations. Do not label this app “HIPAA exempt” or “HIPAA compliant” by assumption. |
| Product classification: [FTC/HHS/FDA interactive tool](https://www.ftc.gov/business-guidance/resources/mobile-health-apps-interactive-tool) | Review intended use and claims, including calculators, PK displays, symptom flags and lab interpretation; decide whether regulatory review is necessary. |

## Mandatory submission checklist — brief §11, all twelve items

Every box requires a named reviewer, dated evidence and an owner decision. “Not in this build” requires proof that the relevant code, data, routes and entitlements are absent; it is not an unreviewed waiver.

- [ ] **11.1 Scope:** onboarding, Settings and each Stack calculation disclose logging/calculation/education scope; no diagnosis, treatment or efficacy claims; clinician consultation copy reviewed. Owner + clinical reviewer; screenshots and copy audit.
- [ ] **11.2 Age:** v1 18+ gate, age-appropriate rating and counsel-reviewed age assurance/data minimization. An age gate does not itself establish compliance with children's rules. Owner + counsel; onboarding/rating evidence.
- [ ] **11.3 Stack:** explicit opt-in, hide/disable controls, region/store kill switch and build without Stack; no dose suggestions; unknown half-life disables curves. STK-06 eligibility resolved or calculator omitted. Owner + clinical/policy reviewers; build and feature-flag tests.
- [ ] **11.4 No sourcing:** no vendor links, affiliate sales, marketplace or public protocol/dose sharing. Private supplier notes are not turned into referrals or a searchable vendor directory. Owner; content/route/seed audit.
- [ ] **11.5 Store policy:** human read of current Apple and, when relevant, Google policies; full submission disclosure, health declarations, accurate privacy labels and age ratings. Owner + counsel; dated policy decisions and listing review.
- [ ] **11.6 Privacy:** data inventory, minimization, purpose-specific consent, retention schedule, export/delete and processor deletion; legal questions above resolved. No health-data ads, sale, third-party SDK disclosure or model training. Owner + counsel + security; contracts and end-to-end tests.
- [ ] **11.7 Body-image safety:** reviewed hide-numbers mode, body-neutral wording, support resources and suppression of optional streak/fasting features on risk signals. Brief defaults (1,200/1,500 kcal, ≤1% weekly loss, BMI <18.5 deficit block) are provisional product guardrails, **not universal safe intake or diagnostic thresholds**. Clinician must approve applicability, unknown/unspecified sex handling and override flow. A checkbox is not medical clearance. Owner + clinical reviewer; risk-scenario tests.
- [ ] **11.8 Accuracy:** estimates expose method, source date, uncertainty and missing-data coverage; AI-derived estimates show ranges; illustrative active amount is never called blood concentration; golden/property tests and user-facing calculation notes approved. Clinical + engineering reviewers; [calculation specification](HOW_WE_CALCULATE.md) and test evidence.
- [ ] **11.9 AI:** AI-06 pre/post controls, ≥100-prompt safety suite; no dosing/titration/stacking/sourcing/diagnosis/extreme-diet advice. Nutrition numbers are retrieved from identified database records; critical entries require confirmation; manual use works with AI off. AI owner + clinical/privacy reviewers; evaluation report.
- [ ] **11.10 IP:** no competitor assets, wording, branding or copied proprietary programs; all data/media/dependencies have approved license/provenance records and notices. Owner + legal reviewer; [license ledger](LICENSES.md).
- [ ] **11.11 Anti-doping:** relevant reference records carry source, applicable list year, effective date and review date; refresh annually and on corrections. “Not found” is not “permitted” or “safe.” [WADA 2026 list](https://www.wada-ama.org/sites/default/files/2025-09/2026list_en_final_clean_september_2025.pdf), effective 2026-01-01, was verified 2026-10-07; no compound classifications were audited. Content owner; current-list review.
- [ ] **11.12 Release:** all eleven gates above and §10.2 security controls below have evidence; residual risks explicitly accepted by authorized reviewers; owner signs the exact build/markets/date. **No store submission is authorized by this Phase 0 document.**

## §10.2 security checklist

- [ ] Versioned MASVS/MASTG/profile assessment: baseline for app, stronger review for Stack; no unsupported certification claim.
- [ ] Keychain/Keystore secrets, protected storage and biometric lock verified on device.
- [ ] TLS, least-privilege credentials, input validation and authorization/RLS on every server table, object and sync path verified.
- [ ] Health values, photos, free text and identifying health context absent from analytics, logs and crash attachments.
- [ ] Dependency/license and secret scans enforced; incident-response plan exercised.

See [SECURITY.md](SECURITY.md) and [TEST_PLAN.md](TEST_PLAN.md) for evidence requirements. Sign-off fields: build/hash **TBD**, markets **TBD**, owner **TBD**, clinician **TBD**, counsel/policy reviewer **TBD**, security reviewer **TBD**, date **TBD**. All remain open.
