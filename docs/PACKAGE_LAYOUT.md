# Package layout and dependency rules

Phase 0 adds architecture artifacts only. Existing `Caliber (DEV).xcodeproj` and `Caliber (DEV)/{App,Models,Views,ViewModels,Services,Utilities,Resources}` remain where they are. The following is the target layout to introduce incrementally in Phase 1, not a claim that empty packages exist today.

```text
Caliber (DEV).xcodeproj
Caliber (DEV)/                 existing app, composition root, resources
Packages/
  CaliberCore/                 value types, units, pure math/schedule/insight engines
  CaliberDatabase/             GRDB repositories, core migrations, copy importer, sync
  CaliberDesignSystem/         tokens, controls, localization helpers
  CaliberCharts/               chart DTO renderers, accessibility, export
  CaliberFuel/                 diary, foods, restaurants, recipes, targets
  CaliberTrain/                sessions, routines, exercises, stats, rest timer
  CaliberBody/                 weigh-ins, measurements, protected photos, recovery
  CaliberStack/                optional target; private migrations, calculator, schedules
  CaliberIntegrations/         HealthKit, auth, notifications, AI gateway adapters
  CaliberSeedData/             licensed/versioned catalogs and fictional demo fixtures
Targets/                      Watch, widgets, Live Activities (introduced by phase)
contracts/                    JSON schemas and language-neutral golden vectors
architecture/                 registries, tokens, requirement map, SQL proposal
scripts/                      phase verification tools
backend/                      future Supabase migrations, functions and RLS tests
 docs/                        ADRs, methods, safety, verification, traceability
```

Dependencies: App → features/integrations; features → Core + repository protocols + DesignSystem + Charts; Charts → Core + DesignSystem; Database → Core; Integrations → Core/protocols; Core → Foundation only. Stack contains its own database adapter and depends on shared storage primitives without exposing its models to core storage. SeedData is excluded from production persistence paths unless demo mode is selected.

A `RepositoryCommand` owns atomic persistence; a view model owns presentation/cancellation; a pure engine owns calculations. No model directly calls a network SDK. Dependence on concrete services occurs only at composition. Typed results distinguish unavailable/unknown, permission denied, conflict and real zero. Errors shown to the user are localized; logs contain allowlisted category and correlation ID, no user values.

Android later shares SQL/JSON conventions, test vectors and algorithm specifications, not SwiftUI or SwiftData. Keep tests for each implementation against the same fixtures to avoid subtly different health math.

Schema and registry files are complete Phase-0 artifacts. Future implementation test IDs in requirements.json are planned contracts, not passing tests or placeholder runtime code.

## Current design integration

`Packages/HeliosDesign` is the imported design implementation from the owner's Claude branch. The app links it directly; `CaliberDesignSystem` adapts its semantic colors for existing `CaliberCharts` callers. Dependency direction is App/CaliberDesignSystem → HeliosDesign → SwiftUI/Foundation; it has no health-data or network dependency. `design/tokens.json` generates the Swift tokens and the look-book CSS.

## Imported engine packages

`Packages/HeliosTime`, `TrainingCore`, `NutritionCore`, `StackCore`, `InsightsCore`, `FoodCore` and `RestaurantCore` are pure Swift engines imported from the owner's Claude branch (D109). Each depends only on Foundation and, where needed, `HeliosTime` (`RestaurantCore` also uses `FoodCore`). They match the `CaliberCore` rule (Core → Foundation only) but remain separate packages until each is reviewed against `HOW_WE_CALCULATE.md`, then linked by the feature that needs it. CI runs their tests in the Foundation workflow; the app does not link them yet.
