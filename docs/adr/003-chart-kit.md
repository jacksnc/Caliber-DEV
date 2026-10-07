# ADR-003 — One native chart contract, many composed views

Status: proposed. Existing WeightTrendChart remains untouched in Phase 0.

Use Swift Charts for standard marks; SwiftUI Canvas/Shapes for heatmaps, synchronized tracks, body/syringe/barbell geometry. Avoid an extra third-party rendering engine until a measured performance failure warrants it. All renderers consume immutable, unit-aware series DTOs returned from rollup repositories; views never query raw health logs or compute dose values.

`ChartCard` owns title, deterministic insight, range/compare controls, method sheet, coverage, export and accessible table. `SeriesRegistry` defines stable metric IDs, domain, unit, aggregation, privacy, flag, query ID and method version. SQL query text is compiled/allowlisted in repositories, never executed from a downloaded registry. `EventRegistry` defines timestamps/local dates, glyphs and sensitivity. One registration adds a series to eligible chart pickers; no generic interface can bypass Stack authorization.

Date domains and a shared cursor live in a `TimelineCoordinator`; vertical scrolling does not re-query. Aggregate daily data once; memoize by account, store revision, method version, range, week start and unit settings. Downsample rendered lines with LTTB after calculations, retaining extrema, endpoints, gap boundaries and event-linked points. Full-resolution values remain available to crosshair lookup and export. Never use downsampled data for correlations or estimates.

Raw points are real observations. Gaps split line segments; dotted interpolation requires opt-in. Bars start at zero. Normalized overlays explicitly label the normalization and never relabel values as original units. Minimum N/span/noise gates suppress weak projections, keep denominators/coverage visible, and say 'No clear trend yet.' Trends are descriptive.

Accessibility: textual summary and a chronological data table for every chart, non-color shapes/patterns, VoiceOver rotor navigation, Dynamic Type, Reduce Motion, and hidden-numbers behavior for visual text, AX text, exports, notifications and cached previews. Graph tables paginate large history. Geometry is not the only means of reading a value.

Budgets apply on a named physical mid-range device in release configuration, not inferred from simulator screenshots: first paint p95 <150ms (1 year and the stricter §3 target for 5 years); also report the §10.2 five-year <400ms threshold, scroll/scrub 60fps. Precomputed cache cold/warm runs are reported separately. A 12-month fictional demo plus 5-year stress fixture are mandatory. Phase 0 delivers contracts, not measured rendering performance.
