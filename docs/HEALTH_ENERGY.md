# Apple Health activity adjustment

This implementation reads only today's Active Energy. It requests no write
permissions and never exports Health values to widgets, the account backend,
logs, analytics or disk. The existing settings/goal database is not migrated.

In Profile → Settings → Active Energy and Calorie Adjustment:

1. Connect Apple Health. A real iPhone presents Apple's read-permission sheet;
   choose whether to allow Active Energy. A completed request does not prove
   permission was granted. No readable samples means unavailable, not zero.
2. Enter the daily active kcal already included in the base goal and explicitly
   confirm/save it. Caliber cannot infer this from an activity multiplier.
3. Turn on Adjust Today's Calorie Goal. Reading alone never enables adjustment.

All math inputs are canonical kcal, even if Today displays kJ. The allowance field
is explicitly labeled kcal. The estimate is `base + max(0, active - allowance)`;
base 2,000 / active 450 / allowance 300 displays 2,150 kcal. Macro goals and saved
base are unchanged. Review the allowance when changing base/activity settings.

Health observations are held in memory only. A new read replaces the old value.
Disconnect, hiding numbers, Demo mode, backgrounding, query errors or missing
readable data clear it. No credit is used for a wrong local day/timezone, future
refresh time, invalid/overflow values or age of at least 15 minutes. The status
is shown under today's goal, including fallback to base. The app refreshes on
return, manually and every five minutes while active, without background polling.
A HealthKit statistical Active Energy sum is queried from local midnight; the
app never sums raw device samples or also adds workout/resting-energy records.
Source overlap and actual Health permissions must still be checked on hardware.

Independent review: Claude reviewed the pure calculator at 31c1e63, found no
blocking flaw and requested stronger boundary/unit/replacement tests. Codex
added a fresh-observation midnight vector, DST dates, the 899-second/fractional/
kJ vectors and a controller test where a changed reading replaces the credit.
Peer comments are review evidence, not a medical or runtime certification.

Simulator tests use FixtureActiveEnergyService with fictional 450 kcal and
in-memory logs. They cannot establish real HealthKit authorization or wearable
accuracy. Physical setup requires a signed build with the HealthKit capability;
no team/account, actual permission, owner data or installed personal build was
changed. See parallel/cards-widgets/VERIFICATION.md for native evidence and open
release checks.
