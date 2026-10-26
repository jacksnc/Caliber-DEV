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

### Local starting target implementation — 2026-10-24

The Profile screen now implements the Mifflin–St Jeor starting estimate above. The user explicitly selects the `+5` or `−161` published equation form; Caliber does not infer it from a name, appearance, or gender identity. Maintenance is resting energy multiplied by exactly one selected activity factor. Cut/bulk adjustments use the requested percentage of current body weight and the brief's `7,700 kcal/kg ÷ 7 days` arithmetic. This is a simple starting estimate, not the later adaptive expenditure engine or a promise of weight change.

For the default balanced starting macros, protein is `2.2 g/kg` for a cut and `2.0 g/kg` otherwise. Fat is the larger of `0.6 g/kg` and `20% of target energy ÷ 9`; carbohydrates receive the remaining energy at `4 kcal/g`; fiber is `14 g per 1,000 kcal`. A negative carbohydrate remainder fails instead of producing an impossible target. Every saved manual calorie goal must also meet the selected form's product floor.

The pure engine blocks cut targets below BMI 18.5, rejects a weekly loss rate above 1% of body weight, and raises a calculated target to the product floor of 1,200 or 1,500 kcal for the selected equation form. There is no clinician-override flow yet. Pregnancy, breastfeeding, eating-disorder risk screening, Katch–McArdle, adaptive estimates, step-informed activity, and clinical suitability review remain release gates for full FUEL-20/BODY-07 completion.

## Stack arithmetic — calculator gated; logging slice implemented 2026-10-26

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

**Implemented logging slice (D111).** Schedules, dose states (due within 12 h, then missed; on time within 60 min) and the double-dose check (a dose within max(1 h, 25% of the expected interval) of the last one asks first) use `StackCore`. Supply left = doses in the current supply − doses taken since its start date. The illustrative estimate uses only the instant-absorption formula above, from a half-life the person entered with its source, and is off unless `feature.stk-10` is on. Amounts are stored as exact decimal strings; units are never converted. No calculator is shown.

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

## Offline foods and barcode portions — implemented 2026-10-14

USDA Foundation values describe **100 grams of the food in the preparation named**. Select raw/cooked/ripe versions carefully. For a selected mass, multiply each source nutrient by `entered grams / 100`. Keep full precision when saving; round only display text. USDA energy uses the available specific Atwater value first, general Atwater second, then reported kcal. Calories are not replaced with `4P + 4C + 9F`. Missing/negative/nonfinite nutrients and wrong units are excluded from this small catalog, never filled with zero. A published zero is retained. The bundled 311 foods are not all of FoodData Central.

A barcode product uses a complete explicit label basis: for example 30 g, 100 g, 100 ml or a stated serving. For an explicit mass basis, `portion nutrient = basis nutrient × entered grams / basis grams`. For volume/serving without gram mass, use a number-of-portions multiplier; never assume ml weighs the same as g. Current Open Food Facts `carbohydrates-total` is required for total carbs; its net carbohydrate field is not a substitute. Ambiguous, prepared, estimated or incomplete records produce a fallback message.

Editing macros replaces the values **for the selected portion**, then the number-of-portions multiplier applies once. A new personal food and immutable diary snapshot are saved; the reference catalog is unchanged. Changing the gram amount resets a pending override so values are not accidentally carried to a different portion. Invalid/nonpositive mass/quantity and nonfinite/overflowing totals are rejected. Barcode check digits establish code integrity, not nutrition accuracy; users still compare the returned label values and serving.

The normalized migration rehearsal preserves original diary snapshots and serving values as typed data when serving grams are unknown. It does not convert arbitrary servings to per-100g nutrients. Original lb values and timestamps stay available; kg uses 0.45359237 and local dates use the explicitly recorded timezone assumption. No new weight trend or calorie-target estimate is introduced.

## Recent foods, favorites and repeat logging — implemented 2026-10-14

Recent foods are ordered by their latest logged timestamp. Frequently logged foods are ordered by the number of distinct diary entries, with latest use and a stable identity as tie-breakers. Quantity is **not** a frequency score: a log of 2 portions counts as one log. Future calendar days, invalid nutrition and missing foods are excluded. The newest valid logged quantity is the default when opening a repeat review. The index uses the current selected calendar's end-of-today boundary; it is not a nutrition trend or an estimate of adherence.

An exact content key groups food copies with the same name, serving description, source, nutrition and menu identity. It deliberately keeps raw/cooked variants and edited nutrition apart. Favorite keys are stored locally; their source foods or saved personal copies provide the displayed nutrition. Favoriting a personal food saves it to My Foods; removing the star does not delete the food or earlier logs.

For weight ounces, `grams = ounces × 28.349523125`. For a source portion with known mass, `grams = count × source portion grams`. The review then uses the same source-to-grams nutrient scaling as before, once. Changing display units keeps the exact selected mass and any macro override; typing a different amount resets the override. No rounding is introduced into the saved calculation. Without source mass, only the original serving multiplier is available; fluid ounces, cups, tablespoons, density and cooked-yield conversions are not invented.

Copying a meal/day freezes each selected food's per-serving nutrition, quantity, serving/source details and note, then creates a new independent log at the chosen destination date. A selected destination meal replaces the meal slot; otherwise each original meal is retained. Copy preview and save use identical validation/totals. Missing/invalid selected foods block copying until excluded or corrected. Aggregate overflow is rejected. Previous day means the calendar's previous day, which can span 23 or 25 hours at DST changes, not a fixed subtraction of 86,400 seconds. Repeating a food through its ordinary review reuses nutrition/quantity; copying a meal/day also preserves its entry notes.

## Source-defined household measures — implemented 2026-10-14

The expanded catalog contains 311 Foundation foods from April 2026 and 7,793 SR Legacy foods from April 2018. Each nutrient still uses 100 g of the named preparation. The older SR data remains explicitly labeled historical; it is not a current package label or restaurant menu.

Only a source-supplied gram weight makes a household measure available. `selected grams = number of measures × source gramWeight`; then `nutrient = source nutrient per 100 g × selected grams / 100`. USDA's `amount` is already part of the displayed measure label, so it is not multiplied into gramWeight again. Example from the pinned rice record FDC168878: 1 cup = 158 g; 2 cups = 316 g and 130 × 3.16 = 410.8 kcal. FDC172470's 2 tbsp serving weighs 32 g, so one such measure is 32 g, not 64 g. Full numeric precision is retained, with display formatting only.

Changing the unit/measure keeps the same food mass and any personal macro edit; the count is converted. Enter 1 to choose one complete displayed measure. Typing a new number resets a pending macro edit. Saving records the resolved grams and, when a household measure is selected, its entered count/label in the existing serving text. No ml-to-g, unlisted household measure or raw-to-cooked yield is inferred.

Search requires every normalized word prefix, gives exact words/phrases higher relevance, and prefers Foundation for relevance ties before stable name/ID ordering. Accented text and punctuation are normalized for search only; displayed preparation names remain unchanged. This source preference is a search rule, not a personal health estimate or guarantee that a food matches a user's label.

## Packaged label bases — implemented 2026-10-15

USDA Branded values use 100 g **or 100 mL**, based on the explicit provider serving unit. [USDA's documentation](https://fdc.nal.usda.gov/GBFPD_Documentation/) describes this standardization and explains that missing nutrients are not zeros. A source serving scales each reported nutrient by `source serving quantity / 100`. A mass serving supplies its stated gram basis; a liquid serving remains a volume portion with no gram conversion. Number-of-portions then multiplies that source serving once. Reported kcal are retained rather than recomputed from rounded macros.

Pinned-record checks: FDC 2212186 reports 393 kcal/100 g and a 28 g serving, producing 110.04 kcal; 56 g gives 220.08 kcal. FDC 2475195 reports 44 kcal/100 mL and a 250 mL serving, producing 110 kcal; two source servings give 220 kcal with no inferred 500 g. These verify source math, not present-day package labels. Personal overrides apply to the reviewed source portion before its count multiplier.

Barcode identity uses checksum-valid canonical GTIN14 text, preserving leading zeros and UPC/EAN equivalence. The source pipeline excludes reserved all-zero values and ambiguous latest versions; a checksum does not prove assignment or label correctness. Current-package comparison remains necessary. Missing local products can be entered manually; only an explicitly configured/permitted remote provider can receive a lookup.

## Restaurant import servings — prepared 2026-10-15

Every imported number describes the complete servingDescription supplied by the permitted source. A known servingGrams value permits `nutrition × selected grams / servingGrams`; unknown mass permits only a count of the stated portion. No density, household mass, cooked yield, side inclusion or recipe modifier is guessed. Source kcal are preserved rather than reconstructed from rounded macros. Personal overrides replace values for the reviewed portion, then any portion count applies once. This importer adds no nutrition estimate and currently ships with zero real imported menu items.

## Recipe and reusable-meal portions — implemented 2026-10-24

Each ingredient begins with complete nutrients for its displayed source portion
(for example, one saved-food serving or 100 g from the USDA catalog). The user
enters how many of those portions go into the batch. For each nutrient,
`batch total = sum(source portion nutrient × ingredient quantity)`. The app keeps
reported calories as supplied; it does not reconstruct calories from rounded
protein, carbohydrate, and fat.

`per-serving nutrient = batch total / entered batch servings`. When the user has
measured the cooked batch weight, `cooked-gram nutrient = batch total × selected
cooked grams / measured cooked batch grams`. A raw-to-cooked yield ratio appears
only if both measured values are entered: `measured cooked grams / measured raw
grams`. This ratio describes measured weight change only. It does not change
nutrition, estimate water loss or nutrient retention, or convert ingredient
weights between raw and cooked states. No density or unmeasured serving weight is
assumed. The user can instead enter a manual ingredient with explicit portion
macros, including a current package label. Every logged serving is a personal
snapshot; a personal macro override replaces the portion values for that diary
entry only.

## Theme integration — 2026-10-25

Graphite/Frost changes presentation only. Today and Diary still use the same `MacroCalculator` totals; weight charts still display recorded readings. No goal, portion, nutrient, workout-volume, or weight calculation changed. Color and placement never change a saved value.
