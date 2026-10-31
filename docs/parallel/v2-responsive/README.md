# V2 responsive native-width checkpoint — verified

Native seed ab5320b is published on codex/v2-native-integration. Codex continues
in /Users/jcrock/Documents/Codex/Caliber-v2-responsive, branch codex/v2-responsive.
The owner explicitly requested continued work after the overnight window ended.
The expired eight-hour automation was deleted on 2026-10-31; this is an active
chat task, not an extension of unattended scheduled work. Read SESSION.md for
actual results. Preserve all existing clones, stores and branch work.

## Plan

1. Carry forward the verified native seed.
2. Center wide content, navigation and review controls.
3. Preserve font scaling and stable field bindings.
4. Check real phone/tablet rotation and saved/draft state.
5. Inspect full captures, record limits and publish the separate branch.

## Ownership and actual dispatch

| Role | Bounded assignment | Files |
| --- | --- | --- |
| Codex | Readable centered content and floating navigation on wide screens; integration and native QA | Views/Components/CaliberAppearance.swift, Views/Navigation/CaliberTabBar.swift, shared food footer; central tests/docs; one stable set-field identifier in ActiveWorkoutView |
| Claude Opus5.5 | Native set-grid delivery e9d41cb already integrated and compact-tested; idle, no new responsive task dispatched | Native handoff retained in ../v2-native/CLAUDE_HANDOFF.md |
| Gemini on owner's Mac | Native food handoff cf70732 already reviewed; idle, no responsive task dispatched; original dirty clone preserved | Native handoff retained in ../v2-native/GEMINI_HANDOFF.md |
| Codex read-only reviewer | Review pending width changes and test gaps; completed without edits or simulator use | No source ownership |

App paths are under Caliber (DEV). Shared schemas, formulas, stored weights,
datasets, provider settings, flags, locks, entitlements and public releases are
frozen. The Progress/global unit-preference issue is a separate central follow-up,
not authorization for either peer to edit settings. No new engines or graphics.

Codex can use a centered readable column on wide windows without changing phone
navigation or text sizes. Claude must not duplicate editable set rows in
ViewThatFits alternatives: keep one stable set of fields/bindings while changing
layout, including field labels/header together. Preserve unsaved fractional
weight/reps, completion, undo, collapse/resume, current/previous values and IDs.
Do not shrink/cap fonts or truncate names to fit.

## QA and evidence

- Run Xcode UI checks one QA device at a time on this Mac. Concurrent cold starts
  stalled before app code; source/documentation review can proceed independently.
- Native phone: Codex Compact QA2998CE67-7D71-460B-AD69-76DAA4D014F6 (375pt) and
  Lookbook QA60A77BA7-5A23-4A5B-8405-B089F66D6B9F (402pt), portrait/landscape.
- Native tablet: Codex uses Caliber Tablet QA B02CFF79-2810-4011-B8CF-72F205F5ACC5,
  iPad Air11 M4/iOS27. Gemini's prepared Responsive Food QA
  5D7C631F-9588-4331-A1C9-06080C59507D has not been used or assigned. Do not use
  an arbitrary first booted simulator, owner personal device or another role's
  device. Gemini's original QA4387978B-A0DF-4A04-9525-19805A4340E0 remains separate.
- Check Frost first, then Graphite: default/large text, keyboard, meal/query/date
  and portion persistence across rotation, readable widths, 48pt controls, long
  food/exercise names, empty/no-goal and privacy states.
- Foldable means adaptive-width study here. Do not claim an Android build or
  physical foldable/iPad split-window verification from a browser/device mock.
  Distinguish actual native widths from source arithmetic and HTML studies.
- Keep result summaries, captures, exact revision/device/orientation and repro
  steps for every finding. Failed or unvisited cases remain failed/pending.
- Use explicit xcodebuild destinations, private derived data/results and
  -collect-test-diagnostics never; keep normal assertions, warnings and captures.
  No billing changes, provider activation, resets or personal data.

Next, after responsive validation: independent Frost beta, then bounded widget
and original-graphics studies in ../lookbook-v2/NEXT_STUDIES.md. The syringe stays
a fictional design prototype; STK-06/live calculators remain gated.
