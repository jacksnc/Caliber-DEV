# Local V2 preview — 2026-10-31

## Scope

Owner explicitly asked to see a local build. That authorizes this preview update
despite the earlier parallel-work rule to leave the personal checkout/device
alone. Peer agents still have no ownership of that checkout or personal store.

1. Choose the verified84edf55 checkpoint, not the untested new compact-Diary patch.
2. Back up the existing simulator app/data and all three local source edits.
3. Fast-forward the personal checkout without stashing or overwriting its edits.
4. Install the exact previously verified binary and check preserved data files.
5. Launch normally and visually confirm the new Diary in Device Hub.

## Result

PASS. Owner source checkout codex/local-preview advanced8f71cff→84edf55.
All three pre-existing scheme/localization edits match their backup hashes
byte-for-byte. No models, services, active schemas or health formulas differ
between those application revisions; no migration or provider change is needed.

Installed the previously compiled and verified Debug simulator application from
/tmp/caliber-v2-responsive-derived/Build/Products/Debug-iphonesimulator. No new
compile/test run is claimed for this preview operation. Code signature verifies;
the recorded source digests match the verified source. Prior focused native and
package evidence remains in ../v2-responsive/VERIFICATION.md and ../v2-native.

Target: ordinary iPhone17 simulator384D80B9-60DE-4538-B135-00D31BB69D2E,
bundleCAL.Caliber--DEV-. Before install, a private offline backup preserved the
previous app bundle,108data files and the three source edits. After install,
all model/photo/preferences files are byte-identical; only four OS-managed
scene/snapshot files changed. Backup location/manifest and personal captures are
private under Library/Application Support/CaliberDevelopmentBackups, outside Git.

Launched with no test, showcase, theme override or fixture arguments. Existing
data opens without a storage-recovery error. Navigated only to Fuel/Diary; no
food, goal, body record, setting or dose was entered. Device Hub's iPhone17
window is raised with the Graphite Diary visible. This verifies a simulator
preview, not a physical-phone install or release build.

The traditional Simulator.app is not present in this Xcode installation; its
actual Xcode → Open Developer Tool → Device Hub entry displays the running
device. A remote AX snapshot timed out after the Fuel tap; fresh state confirmed
the tap succeeded and the Diary is visible. No app restart or data reset was used.

## Remaining work

Claude7e8813a and Gemini955e1f3 are delivered/fetched but not integrated into this
preview. The newest compact-header/navigation change still needs review/native
QA. Real iPad window resizing, independent native Frost beta and later studies
remain pending. No personal UI/data capture is committed with this report.
