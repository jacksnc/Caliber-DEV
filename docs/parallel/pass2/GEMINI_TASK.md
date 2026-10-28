# Gemini assignment — faster food-entry workspace

Work on `gemini/food-entry-pass-2` from the seeded common base. Read
[coordination and ownership](README.md), root `AGENTS.md`,
`docs/RECORDING_FEATURE_REVIEW.md`, `docs/FOOD_REUSE_VERIFICATION.md` if present,
`docs/RECIPE_VERIFICATION.md` and the existing food-entry tests first.

## Deliver this first PR

1. Refine `FoodSearchView(mealType:date:)` into one clear native food-entry hub:
   compact search/barcode/label/photo/manual shortcuts and useful history/library
   navigation. Existing recents, frequency, favorites, My Foods, meals/recipes,
   typed lists, restaurant results/builders must remain reachable.
2. Put recent foods close to the top and give rows a clear right-side quick action.
   It opens the existing editable review, with the existing last-used portion;
   confirmation still saves the same independent diary snapshot. Retain row IDs
   on existing navigation elements rather than making existing tests find a new
   inaccessible wrapper. Avoid nested conflicting buttons.
3. Carry the selected meal and date through every route, including camera and
   manual entry. Preserve text/drafts across harmless scope changes, and provide
   clear no-results/create-food actions. Keep full macro editing after logging.
4. Reuse Helios components and all existing services. A compact manual-entry
   presentation is welcome if validation, optional library save, serving math,
   cancellation and existing manual-entry expectations are preserved. Do not
   invent zero macros for unknown values or add calorie-only schema semantics.
5. This PR does **not** introduce a multi-food transaction/cart, voice service,
   new provider, recipe discovery/import, schema change or new source dataset.
   Record the smallest follow-up contract for a future shared food draft in the
   handoff; do not ship a placeholder cart or an unconnected mode.

## Boundaries and tests

Do not edit scanner/label/photo internals, Models, App/root navigation, Quick Log,
shared theme tokens, restaurants, Stack, Train, project file, CI or shared test
helpers. Use `FoodEntryPass2*` for new components/test files. Existing capture
screens are linked through their current initializers. Reuse current stable IDs.

Run relevant food reuse, recipe, portion-review and scanner-route UI tests plus
focused new `FoodEntryPass2UITests` where native execution is available. Verify a
backdated meal remains backdated, cancel saves nothing, a repeat uses the last
portion once, macro edits do not alter reference data, and saved meals/recipes
still work. Check Graphite/Frost, largest text and offline/no-result paths.
If iOS tooling is unavailable, label native checks **UNTESTED** with exact commands.

Update only [your handoff](GEMINI_HANDOFF.md), commit conventional changes, push
your branch and return its commit/PR. Codex handles integration and the local build.
