# Series and Event registries

`architecture/series-registry.json` and `event-registry.json` are static allowlisted definitions, version 1. Human IDs remain stable across migrations. Source query IDs name typed repository functions; a registry cannot inject SQL. Each query returns canonical units, local_date/UTC timestamp, sample count, expected buckets, coverage and provenance. `estimated` results include method version, uncertainty/sufficiency and supporting inputs.

## Query contract
Input: authorized account, date range, IANA display zone, week start, optional exercise/muscle/compound dimension, aggregate resolution, store revision and method version. Output: ordered observations `{date, value|null, n, coverage, sourceIDs, flags}`, dimension metadata and method record. Values for Stack quantities retain decimal/integer encodings all the way to labels. Sorting and aggregation use stored local_date; timestamps align within-day event tracks only. `last` breaks ties by recorded timestamp and stable ID, not arrival order.

## Aggregation
Daily sum metrics require explicit logged/completeness status: an unlogged intake day is null, a confirmed fast/zero intake day is a measured zero. Body day value is the last valid chronological weigh-in with raw readings available in drill-down. Set rollups use the currently resolved revision and captured bodyweight, exercise/muscle weights and method version. Weekly sums are sums of day buckets in user week-start order. Distinct workout frequency cannot be obtained by summing per-exercise counts; aggregate unique workout IDs before deriving that series.

Derived weights/trends/expenditure remain versioned estimates. A logged source change invalidates that day and the necessary downstream trend/forecast window. Rollup rebuilding is deterministic/idempotent, off main thread, in bounded transactions, and parity-tested against raw snapshots. Registry registration does not implement an engine.

## Privacy
Stack series live only in its own store and registry. Core series do not reference doses. The UI combines authorized arrays in memory when unlocked; disabled or locked Stack yields no values, labels, counts or event hints. Hide-numbers applies to data tables, AX text, tooltips, insights, exports and rendered thumbnails. Export is an explicit user action with a redaction preview.

## Availability and performance
P1 definitions carry explicit default-off flags; engines/queries cannot be reached merely because a registry entry exists. UI contracts display 'Not enough data' for unmet gates. Bounded caches are invalidated on account/consent change. Full-resolution arrays feed math and CSV; rendering may downsample only after calculations. Performance budgets and benchmark environment are recorded in TEST_PLAN.md.

## SQL projection limits

The SQL `body_daily_raw` mean/min/max view is a descriptive raw-data summary; it does not define the last-reading-per-day input to EWMA. `nutrition_daily_raw` covers eaten food rows only; the future typed repository must reconcile all energy-bearing sources and explicit `nutrition_days` completeness before target/expenditure queries. These SQL views are not complete runtime chart engines.
