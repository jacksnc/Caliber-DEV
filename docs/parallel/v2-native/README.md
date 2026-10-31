# V2 native iPhone batch

Begins after the reviewed Lookbook V2 checkpoint. Same approved eight-hour window:
stop new batches at 2026-10-31 05:52:48 UTC. Read AGENTS.md, LOOKBOOK_V2.md,
parallel/lookbook-v2/VERIFICATION.md and your role task. The book and peer design
handoffs are integrated; do not restart the HTML task or modify the design source.

| Role | Branch | Ownership |
| --- | --- | --- |
| Codex | codex/v2-native-integration | DiaryView.swift, diary-specific presentation/tests, FoodShortcutsUITests reveal helper, central integration/docs |
| Claude Opus 5.5 | claude/v2-native-surfaces | TodayFoundationView.swift, Views/Train/, Views/Progress/, Stack/StackHomeView.swift; CLAUDE_HANDOFF.md here |
| Gemini Argon on Mac | gemini/v2-native-food | FoodSearchView.swift, FoodEntryPass2Components.swift, FoodNutritionReviewView.swift, SavedFoodDetailView.swift, Views/Components/MacroOverrideSection.swift; existing food-entry tests; GEMINI_HANDOFF.md here |

App paths are below Caliber (DEV)/. Existing tests below Caliber (DEV)Tests and
Caliber (DEV)UITests follow the matching role. No shared token, project, root
navigation, model/service/math/storage, Settings, privacy-lock or provider edits.
Use existing semantic Helios APIs; keep new helpers private to owned view files
unless a cross-boundary request is handed to Codex. No shared API change needed.
Native adaptations must preserve behavior, selectors and every save/cancel/undo
path. No new cross-domain data engine, calculator, protocol advice or P1 flag.

Separate clones/worktrees; push only your assigned branch. Peers do not merge
Codex or each other after seed. Update role handoffs only; Codex aggregates docs.
Personal simulator/local-preview is reserved for the owner and not touched.
Codex QA: Caliber Lookbook QA 60A77BA7-5A23-4A5B-8405-B089F66D6B9F.
Gemini QA: Caliber Food Entry QA 4387978B-A0DF-4A04-9525-19805A4340E0.
Use explicit private derived-data paths and fictional isolated stores; never
install on/reset another role's simulator. Claude cloud: native checks UNTESTED
until Codex verifies. App implementation must not copy mock numbers into users'
goals, foods or progress. No new app icon, purchased assets or dependencies.

Codex owns the FoodShortcutsUITests.swift reveal helper integration fix; Gemini
was notified to leave that file unchanged. The helper must tolerate hidden
primary navigation bars. Do not run scripts/test_ios.py as-is: it auto-selects
a booted iPhone. Use explicit QA destination IDs in direct xcodebuild commands.
