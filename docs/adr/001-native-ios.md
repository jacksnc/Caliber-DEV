# ADR-001 — Preserve the native iOS application

Status: proposed for Phase 1 approval. Scope amendment: Android Phase-1 acceptance remains pending.

## Context and decision
The source tree is a working SwiftUI/SwiftData app, despite the brief's README-only repository assumption. Keep its Xcode app and evolve features in-place. Create local Swift packages gradually: Core, Database, DesignSystem, Charts, Train, Fuel, Body, Stack, Integrations and SeedData. Core has no SwiftUI/SwiftData/HealthKit dependency. App composition owns navigation, dependency injection, settings and feature availability. Repository protocols, DTOs and value types isolate the current persistence layer.

Use Swift Concurrency actors for storage/import work, `@MainActor` view models for UI, Swift Testing for pure Swift, XCTest/XCUITest for integration and flows. Enforce compiler warnings/concurrency checks incrementally; future CI pins the toolchain and package revisions. Retain existing FoodSearch/Barcode/AIScanner/RestaurantLibrary abstractions. The app can read legacy models until each repository-backed flow is verified.

Alternative rejected: React Native/Expo now. It would rewrite completed native work, add native bridges for the iOS-focused features, and contradict the owner's earlier SwiftUI preference. This ADR uses the native alternative explicitly allowed by §10.1. Kotlin/Compose can later consume versioned JSON formats and golden vectors; Swift source is not presented as cross-platform code.

## Compatibility and acceptance
Proposed minimum iOS 17; current target is 27.0 and remains unchanged this phase. Phase 1 must audit APIs, create availability fallbacks where needed, test the minimum and current iOS, and change deployment settings only when builds actually pass. Watch/widgets/Live Activities remain native targets. The Phase-1 Android-emulator criterion is not silently marked passed: owner must approve deferral or choose a cross-platform rewrite before implementation.

## Consequences
No pnpm workspace, Zustand, zod or React testing scaffold is created solely to imitate the default stack. Shared contracts use JSON Schema plus generated/validated Codable models. The logical package boundaries and coverage obligations from §10 still apply. There is no Android implementation or Android performance claim in this delivery.
