# iPhone nutrition widgets

Small and medium widgets open Fuel; medium also opens Add food. The extension
reads one versioned JSON snapshot, never SwiftData or the app's database files.
System light/dark selects Frost/Graphite. No goals, inferred balance or clinical
information is exported in this version.

The Fuel URL returns to today's diary when it is safe to navigate. An active
food form, Profile, Quick Log or check-in draft holds the request until finished
or cancelled. A pushed Food Library branch is preserved until the person returns
to its root. Add food opens editable search without inserting a record; repeated
Add links keep the existing search/review. Number-free and Demo mode reject both
links and clear pending requests. This is ephemeral navigation, not widget data
sharing or background logging. See parallel/integrated-iphone/VERIFICATION.md.

## Privacy contract review

New App Group: `group.CAL.Caliber-DEV.widgets`, used only by this app and its own
WidgetKit extension. Only `nutrition-widget-v1.json` is written. Its allowlist is
four recorded daily totals (kcal/protein/carbs/fat), generated/expiry/day dates
and timezone identifier. No identifiers, foods, notes, photos, weight, Stack,
HealthKit, tokens, source records or database paths. No network code.

The person must turn on Show Nutrition on Widgets in Settings. It is off by
default. The setting explicitly explains Home Screen visibility. Hide Calories
and Weight and Demo mode suppress writes and remove the file. Test launches use
a separate temporary cache rather than the App Group. Atomic file replacement,
iOS complete file protection and backup exclusion protect the exported cache.
Protected/unreadable/invalid/missing data fails to a neutral view. Sensitive
visual and accessibility content must both respect widget redaction.

A snapshot expires after two hours or local midnight, whichever comes first.
Timezone mismatch, future/old date or bad values hide figures. The provider emits
a neutral expiration entry and no polling schedule. Successful app saves and
consent/lifecycle/day/timezone changes request a WidgetKit reload. Reload timing
is controlled by iOS; turning off removes the data file but is not a guarantee
that an already displayed system snapshot redraws immediately. Daily totals are
estimates of logged intake, not a real-time display or calorie recommendation.

Reviewed boundary: Codex source review permits this minimized, explicit opt-in
cache. It does not permit whole-store sharing, private health data in logs or
analytics, lock-screen families, workout/Stack widgets or interactive logging.
Small widgets route through one root widgetURL; only medium widgets use discrete Link controls.
Hardware lock/unlock/redaction and provisioning must be verified independently
before claiming release readiness. No owner's setting was turned on.

## Running

Build the Caliber (DEV) scheme for an iPhone simulator. The app embeds the
CaliberWidgets extension. On a QA iPhone, hold the Home Screen, choose Edit → Add
Widget → Caliber → Daily Nutrition. Start with the neutral small and medium
widgets, then explicitly enable Show Nutrition on Widgets in Caliber Settings
using fictional logs only. Turn it off and verify the exported file is removed;
iOS may retain a previously rendered snapshot until its requested reload.

Physical signing requires the app and extension to share this App Group in the
owner's Apple development team. This change does not register identifiers,
activate an account or change the owner's installed build.
