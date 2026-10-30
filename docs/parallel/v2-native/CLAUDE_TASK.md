# Claude - V2 native surfaces

Use published claude/v2-native-surfaces seed in a separate clean checkout.
Follow README ownership. Translate V2 hierarchy to existing SwiftUI with native
controls, semantic Helios typography and opaque text surfaces. Priority: Today
and Progress first, then bounded Train/Stack presentation improvements. Keep
working features and app architecture; do not reproduce HTML implementation
notes or add giant fixed frames. Number-free and locked Stack must not expose
measurements or private entry names/times through visible text or accessibility.

Today: clear balanced nutrition summary and continuation card. Progress: clean
weight chart + existing photo/weight/notes timeline. Train: readable current-set
rows, existing logging actions and history. Stack: discreet existing logged/due
items and supply, with current opt-in/authentication routes unchanged. No live
syringe/calculator, dose advice, new adherence/PK engine or new timeline query.
If a book concept lacks a current data route, record it instead of faking data.

Large text: reflow/stack and retain full strings, never minimumScaleFactor,
lineLimit caps or viewport font clamps. Keep 48pt main controls and sufficient
contrast on actual nested surfaces. Reduce Motion/Transparency/Contrast use
existing supported policies. New motion/glass package remains unadopted.

Preserve navigation, IDs, swipe actions, date/calendar/unit/locale choices and
save semantics. No formula, model, source or persistence changes. Test relevant
pure/static checks in your environment, format, review diff; mark native tests
UNTESTED if no Xcode. Commit/push only your branch with exact files/checks,
limitations and native integration notes in CLAUDE_HANDOFF.md here. Do not wait
for an iPad batch or start widgets; iPhone integration comes first.
