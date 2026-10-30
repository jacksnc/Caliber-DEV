# Native implementation map after the design checkpoint

Inspected source at 8f71cff; design changes do not modify these files yet.

| V2 element | Existing native location | Preserve |
| --- | --- | --- |
| Diary date / copy | Views/Diary/DiaryView.swift | Calendar/day filtering, date picker, copy sheet and IDs diaryDate/diaryCopyDay |
| Energy / macros | DiaryView MacroTotalsSummaryView + MacroCalculator + UserProfile | Stored reported kcal; do not infer kcal from grams; explicit saved profile targets only |
| Meal cards / review | DiaryView mealSection, DiaryEntryRow, EditDiaryEntryView | Add/copy/delete/repeat/edit routes, selected day/meal, diaryEntry/diaryAdd/diaryCopy IDs |
| Food hub | FoodSearchView + FoodEntryPass2Components.swift | Existing mock/provider/source rules, recents, future/past date distinctions |
| Quick portion review | FoodEntryPass2QuickReviewTarget + existing detail sheets | Editable four nutrient fields, explicit save, source snapshot and quantity validation |
| Today | Views/Foundation/TodayFoundationView.swift | Existing overview/navigation; no new inferred goals or causal insight |
| Train | Views/Train/TrainHomeView.swift, ActiveWorkoutView.swift | Session persistence, rest/set logic, custom exercise and undo |
| Progress | Views/Progress/ProgressDashboardView.swift, WeightTrendChart.swift, ProgressTimelineRow.swift | Weight/photo/note capture, chart source and accessible alternative |
| Stack | Stack/StackHomeView.swift | Module opt-in, separate protected store, lock/opt-out; no calculator activation |
| Navigation / privacy | RootTabView + Views/Navigation | Optional Stack tab, profile route, persistent Quick Log and dedicated NumberFreeHomeView |

The current Diary rings visualize macro-energy shares using 4/4/9, while the V2
blue ring visualizes reported energy relative to an explicit stored goal. These
are different meanings: label the new ring accordingly, reuse existing calorie
and goal values and test missing/zero/invalid goals, above-goal display and
rounding. Never substitute macro-derived kcal into the diary's stored total.
Do not treat seed targets as defaults for real users without a saved profile.

Native acceptance after implementation: Graphite/Frost, default and AX text,
320-point equivalent/narrow windows, long names, empty day, no profile, manual
macro override, edit/delete/copy/repeat and meal/date routing. Keep System Date
Picker access even if a day strip is added. Preserve List swipe/VoiceOver actions
when restyling. Keep text uncapped; use ViewThatFits/vertical reflow and existing
Helios typography, not HTML dimensions copied into fixed native frames.

No migration is proposed. Native work gets a fresh ownership assignment and
isolated branch after complete V2 book/handoffs; Codex integrates and verifies.
