# How Caliber calculates

Draft explanation · 2026-10-07. The first section describes the current code inspected in Phase 0. Later sections are a **future specification**, not features or medical claims already shipped. Calculations help explain logged information; they do not determine treatment, a suitable dose or an individually safe intake.

## What the current app calculates

**Food totals:** multiply the calories, protein, carbohydrate and fat for one serving by the logged quantity, then add the entries for the day/meal. A supported double ingredient contributes twice its base values. User edits belong to the saved food snapshot, so changing a restaurant menu should not change yesterday's diary.

Calories and macros are independently editable. The app preserves the entered or source-provided calories instead of forcing them to equal a macro estimate. Serving basis and source matter: an estimated photo match or restaurant portion is not a laboratory measurement of the meal actually eaten.

**Weight units:** one pound equals 0.45359237 kilograms; conversion multiplies or divides by that factor. Current `WeightEntry` storage is in pounds. Future canonical-kilogram migration must preserve the original entered number/unit and existing records.

**Current progress summary:** the latest positive finite reading and the change from the first to last reading. The inspected `WeightProgressSummary` does **not** implement a smoothed trend, expenditure estimate or projected date. `NutritionInput` rejects negative/non-finite macro values and nonpositive quantities. These code observations are not a new execution or audit of all app paths.

## Future calculation principles

Every estimate must show its method, source/version, input coverage and limitations. Missing is different from zero. A value users correct remains their value, with provenance retained. Display rounding must not silently alter stored amounts.

Day/week totals will use the recorded local date, IANA time zone and chosen week start; they will not regroup historical entries at UTC midnight. Exact events retain UTC timestamps for elapsed-time calculations. Aggregated series state whether they sum, average, select last or select maximum, and keep gaps visible.

The future pure Swift core takes typed values rather than UI or database models. Dose mass, volume, biological activity and device markings are separate dimensions; dose calculations use integers or fixed-point decimals, never binary floating-point. The current `Double` nutrition helpers are not a dosing engine.

## Training estimates — planned

For load `w` and repetitions `r`:

| Method | Formula | Arithmetic example, 100 kg × 5 |
| --- | --- | --- |
| Epley | `w × (1 + r/30)` | 116.6667 kg, displayed 116.67 |
| Brzycki | `36w / (37 − r)` | 112.5 kg |
| O'Conner | `w × (1 + 0.025r)` | 112.5 kg |
| Lombardi | `w × r^0.10` | 117.4619 kg, displayed 117.46 |

These are estimated one-repetition maxima, not instructions to attempt that load. The brief proposes low confidence above 12 repetitions and default exclusion from e1RM records. RPE adjustment uses effective repetitions `r + RIR`, with `RIR = 10 − RPE`; unlogged effort must not be invented. Mayhew, Wathan and Lander await pinned original formulas and domain rules before implementation.

Volume adds `load × repetitions` for counted sets. Warm-ups are excluded by default. Weighted bodyweight uses bodyweight plus added load; assisted uses bodyweight minus assistance. Dumbbell load is per hand unless “count both hands” is enabled. Muscle attribution defaults to 1.0 for primary muscles and 0.5 for secondary muscles; these are accounting weights, not a measurement of biological stimulus. Hard-set filtering uses RIR ≤4 or unlogged RIR under the brief's convention.

Rep records mean **at least N repetitions**: a heavier set improves every eligible N ≤ its repetitions. Edits/deletions recompute history; a tie does not create a heavier record.

## Nutrition and body estimates — planned

| Calculation | Proposed method | Meaning / limit |
| --- | --- | --- |
| Resting energy | Mifflin–St Jeor: `10 × kg + 6.25 × cm − 5 × age + coefficient`; coefficient +5 or −161 under the published sex-specific forms. Katch–McArdle: `370 + 21.6 × lean mass kg`. | Population estimates; sex-input handling, eligibility and clinical review remain unresolved. Do not infer the coefficient from gender identity or appearance. |
| Activity estimate | Resting estimate × one selected factor: 1.2, 1.375, 1.55, 1.725 or 1.9. | Approximate starting estimate; do not double-count exercise/Health activity. |
| Weight trend | First reading seeds trend; each update uses `previous + gain × (reading − previous)`. α =0.1; over n elapsed calendar days, gain `1 − 0.9^n`. | Smooths variation but cannot explain its cause. Daily reading selection still needs a rule. |
| Expenditure | `mean intake − (change in trend kg × 7,700 / elapsed days)`. Proposed window 14–21 days and ≥70% logged-day coverage. | Negative weight change raises this arithmetic estimate. Missing intake is not zero. 7,700 is a modeling approximation, not a promise of a particular weight change. |
| Target changes | Proposed maximum change of ±150 kcal per weekly update. | A stability constraint, not proof of appropriate intake. Confidence/complete-day definitions remain to be specified. |
| Energy cross-check | `4 × protein g + 4 × carbohydrate g + 9 × fat g + 7 × alcohol g`. | A review flag, not an automatic correction of label calories. Fiber, polyols and label rounding can differ; the >10% comparison denominator is not yet specified. |

Weight-loss projections must be unavailable when evidence is insufficient or the observed direction does not approach the goal. Avoid exact-date promises. Brief calorie floors, BMI and rate caps are provisional product rules awaiting clinical review; none establishes a universal safe intake or diagnosis. Hide-numbers mode must cover charts, summaries and shared surfaces too.

## Stack arithmetic — gated, not implemented

No dose is chosen, recommended, rounded into a recommendation or generated by AI. Any calculator depends on the eligibility review in [COMPLIANCE](COMPLIANCE.md). These anonymous numbers are **test fixtures, not instructions for preparing or taking a substance**.

For a mass-only mathematical fixture, concentration is mass divided by **final solution volume**; draw volume is user-supplied target mass divided by concentration. U-100 and U-40 markings correspond to 100 and 40 markings per mL respectively. Syringe markings are not biological international units. The brief's use of “diluent volume” assumes it equals final volume; actual product instructions must resolve that assumption before a product-specific calculation.

| Synthetic input | Expected arithmetic |
| --- | --- |
| 5 mg / 2 mL; input amount 0.25 mg | 2.5 mg/mL; 0.10 mL; 10 U-100 markings; 20 full amounts |
| 10 mg / 1 mL; input amount 2.5 mg | 10 mg/mL; 0.25 mL; 25 markings; 4 full amounts |
| 2 mg / 2 mL; input amount 0.3 mg | 1 mg/mL; 0.30 mL; 30 markings; 6 full amounts, 0.2 mg theoretical remainder before waste |
| 10 mg total, equal mass components / 2 mL; input draw 0.10 mL | 250 µg of each component |

IU denotes biological activity, not mass. An IU-based amount may only be calculated in a compatible IU concentration; conversion to mg/µg requires an authoritative product-specific potency and a reviewed use case. Pen clicks require that exact product's verified amount-per-click. No universal click conversion, generic “units” field or cross-route assumption is acceptable.

Capacity and unit mismatches block calculation. The proposed <2-mark warning does not imply that larger draws are accurate or safe. Waste/priming and beyond-use dates must come from user/label information, never invented defaults. “Pick a diluent” reverse recommendations remain disabled pending clinical/policy review; the app must not choose formulation instructions.

**Illustrative active amount:** with positive known half-life H, elimination rate `ke = ln(2)/H`. A past logged amount D contributes `D × 0.5^(elapsed/H)` in the instant-absorption model. Future events contribute nothing. If a reviewed absorption model is enabled, use `D × ka/(ka−ke) × (exp(−ke×t) − exp(−ka×t))`, with limit `D × ke × t × exp(−ke×t)` when rates coincide. Rates and elapsed time must use matching units. Unknown/nonpositive half-life disables the curve. This simplified modeled amount is **not blood concentration**, bioavailability, treatment effectiveness, interaction advice or safe timing. Separate compounds are not summed as interchangeable amounts. No clinical targets or next-dose advice follow from the chart.

## Associations and trends — planned

Spearman correlation compares ranks of paired observations; report the paired count, dates, coverage, lag and 95% bootstrap interval. Fewer than 14 pairs is insufficient under the brief. Constant series are undefined, not zero correlation. Even a strong association is not causation or a reason to change treatment. Searching many pairs/lags raises false-positive risk.

Theil–Sen slopes and detrended median absolute deviation (MAD) support descriptive trend gates. Compare **change over a defined span** with noise in matching units, not a per-day slope directly with a value-unit MAD. Inputs, methods and thresholds are stored for the “Why?” explanation. AI may rephrase these facts but cannot invent them.

## Specification decisions and review gates

The explicit §9 numeric goldens are arithmetically consistent. This does not validate the clinical models. Proposed engineering defaults for M01–M11 are now recorded in [DECISIONS](DECISIONS.md). The table below records the original ambiguity; clinical, reference-source and statistical review gates remain open before released engines.

| ID | Missing or ambiguous rule |
| --- | --- |
| M01 | Allowed rep/RPE/RIR domains; 1-rep convention; Brzycki's r=37 singularity; observed versus effective reps for confidence gate; exact Mayhew/Wathan/Lander sources. |
| M02 | Assisted-load floor, unilateral/count-both behavior, edited bodyweight source, interaction of fractional/hard-set filters; rep-record category limits. |
| M03 | Same-day weigh-in aggregation and duplicate order; elapsed-day count across local-date gaps; EWMA recomputation after edit/delete. |
| M04 | Complete intake day, coverage denominator, missingness bias, window endpoints, minimum paired weights, confidence method and timing of weekly clamp. |
| M05 | Sex-specific energy coefficient eligibility, missing body-fat method, “0.6 g/kg or 20%” fat-floor interpretation, negative remaining carbs and target override policy. |
| M06 | Energy mismatch denominator/zero handling; fiber/polyol/alcohol treatment; units and portion basis in imported nutrition. |
| M07 | Final versus added volume; fixed-point scale/overflow; supported instrument increments, intermediate/display rounding, retained remainder and supplied waste. |
| M08 | Product potency/click factors, source validation/expiry, incompatible blends, days-of-supply treatment for PRN/variable schedules. |
| M09 | Absorption lag versus ka, tolerance for nearly equal rates, half-life source validity and permitted modeling use. Accumulation `1/(1−0.5^(interval/H))` requires positive interval/H and must not become scheduling advice. |
| M10 | Spearman ties, lag direction, paired-day alignment, bootstrap type/seed/autocorrelation, multiple-comparison presentation and minimum time span. |
| M11 | Theil–Sen duplicate timestamps, MAD scaling and change horizon; threshold behavior for zero noise, outliers and insufficient data. |
| M12 | Official coefficient editions, categories/units and licensed worked examples for DOTS/IPF GL/Wilks/Sinclair; source and review dates for every reference estimate. |

Named future formulas here reproduce the owner's specification. Original publication/reference selection and clinical suitability have **not** been fully validated in Phase 0. Approved method/source versions must replace these pending entries before publishing the corresponding user feature. See [TEST_PLAN](TEST_PLAN.md).

## Foundation charts and conversions — implemented 2026-10-08

The demo contains fictional observations and never estimates the user's food, training or dose. Its simulation levels are arbitrary units with no compound, regimen or clinical interpretation.

Chart ranges use the dataset's local calendar: the last week, month, three months or year, ending on the latest observation day. Missing days stay missing and break the line. Coverage counts distinct days with a finite observation divided by the displayed calendar-day count; multiple observations on a day do not increase coverage. A measured zero is valid. Tables show unlogged days explicitly. First-to-last change is the final valid observation minus the first valid observation in the window; it is descriptive, not a smoothed trend, causal explanation or forecast. The padded vertical scale is labeled and may exclude zero to make changes readable. No clinical confidence interval is implied.

New unit helpers use 1 lb = 0.45359237 kg, 1 inch = 2.54 cm, 1 kcal = 4.184 kJ and 1 US fl oz = 29.5735295625 mL; °F = °C × 9/5 + 32. Original entered text and unit are preserved separately. Grouping/partial numeric strings, negative mass and nonfinite values are rejected by the new strict parser. Existing food/Progress input adapters retain their prior behavior until their focused locale audit is completed.

The existing Progress graph remains a raw reading graph. Foundation does not yet implement the EWMA, expenditure, strength or dose engines in §9.3. Demo training volume is synthetic seeded data, not a verified live Train calculation.


## Editable decimal inputs

Use the decimal separator selected in Settings. We accept a complete nonnegative decimal, trim surrounding spaces, and reject grouping separators, partial parses, scientific notation, infinity and NaN. Serving quantities and logged weight must be greater than zero. Switching display formats replaces only the separator; it does not change or round stored nutrition or weight. Existing nutrition drafts preserve the full finite value, including very small quantities. These parsing rules are input validation, not a nutrition estimate.
