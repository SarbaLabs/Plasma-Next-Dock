# Validation and desktop acceptance

## Automated environment

Initial local checks use GCC 14, Qt 6.8.2, LayerShellQt 6.3.4, Plasma runtime 6.3.6
and KDE Frameworks 6.13 extracted into an isolated build prefix. They do not use
the maintainer's CachyOS session or a live KWin compositor.

Tests:

- Pure geometry: four edges, negative output origins, bounded surface size, rounded
  contact, zero/oversized radius, icon input and transparent drawing margins.
- Controller with a model fixture: overlap only in the visible capsule, minimized/
  non-window exclusions, hover inhibition, leave grace, absent-protocol fail-open,
  disabled dodge, coalesced notifications and model destruction.
- Qt Quick pointer/render test: continuous magnification between tasks, reset on
  leave, enlarged icon within canvas, transparent margin and painted capsule pixels.
- Four QML smoke cases: demo on each edge with glow enabled.
- Live-model smoke: loads the actual KDE task model offscreen, but does not assert
  real window enumeration, activation or launch success.

Commands for dedicated diagnostics (normal installation uses ./install.sh):

```bash
cmake -S . -B build -DBUILD_TESTING=ON -DCMAKE_BUILD_TYPE=Debug
cmake --build build --parallel
ctest --test-dir build --output-on-failure
DESTDIR="$PWD/stage" cmake --install build
```

QML warnings make the smoke runner fail. Offscreen plugin messages about unsupported
window masks are expected: input passthrough must be tested under Wayland. The test
runner's PND_TEST_CAPTURE environment variable can capture its own QQuickView to a
PNG when used with --smoke-test; it does not capture the desktop.

## Required CachyOS / KWin checks — pending

Run on a free screen edge using the README commands. Keep the current stable dock
installed. Stop the experimental process with Ctrl+C. No Plasma restart is required.

| Scenario | Expected result |
|---|---|
| Demo with 40 px / 1.5× and 96 px / 2.5× | Icons grow without cross-axis clipping |
| Empty transparent canvas | Clicks reach the application underneath |
| Window enters transparent margin only | Dock remains visible |
| Window intersects visible capsule | Dock hides when not being used |
| Move pointer to associated screen edge | KWin recalls dock above normal windows |
| Enter recalled dock, then leave | Usable on hover; hides again if overlap remains |
| Repeated reveal without immediate capsule entry | No permanently stranded/incorrect state |
| Move/minimize/close overlapping window | Dock returns without mouse interaction |
| Switch virtual desktops or activities | Only relevant windows cause avoidance |
| All four edges; negative output coordinates | Correct location, icon orientation and collision |
| Fractional scaling and mixed-DPI outputs | Drawing, input and collision remain aligned |
| Existing panels or fullscreen application | Record actual stacking and recall policy |
| Long task list and scrolling | Tasks remain usable without expanding beyond output |
| Launcher click / running task click | Correct KDE launch or activation |
| Glow on/off; radius 0/10/large | Glow stays inside capsule; no extraction when disabled |
| Selected output disconnects | Process exits cleanly; stable dock stays unaffected |
| Install/uninstall | Only this application's files change; no autostart/Plasma reset |

Native edge recall and QWindow input masks cannot be confirmed by model fixtures
or offscreen rendering. Do not mark this checklist accepted until the maintainer
actually tests it. Record individual failures and fixes here rather than treating
an overall smoke pass as proof of compositor behavior.

## Initial results — 2026-11-13

CachyOS installation exposed a configure failure with newer Qt: the public Gui
package no longer implicitly imports Qt6::GuiPrivate. CMake now explicitly finds
GuiPrivate when the target is absent, retaining compatibility with Qt 6.8. Qt 6.12
also receives the explicit PUBLIC_CODE Wayland generator option to preserve the
adapter's generated API without the QTP0006 warning. Local Qt 6.8 rebuild and all
seven tests pass; compilation on the maintainer's newer Qt remains to be confirmed.

The native executable builds successfully. All seven CTest entries pass locally:
geometry/controller, pointer/render, four edge smoke cases and actual KDE model
loading. Staged installation contains only the executable and its desktop file;
both shell scripts pass syntax checks.

Software captures were inspected for horizontal and vertical capsule placement.
The local Kirigami 6.13 icon texture nodes do not appear in those software captures,
although theme icons load successfully as QIcon pixmaps. Thus these captures are
**not** evidence of complete icon rendering. Continuous hover, icon item geometry
and capsule painting are tested; actual icon rendering and all compositor behavior
remain to be checked on the maintainer's GPU-backed Plasma desktop. No visual parity
with the existing dock is claimed.

## Edge recall follow-up — 2026-11-13

The maintainer confirmed that the prototype runs on CachyOS after the Qt configure
fix. Desktop testing revealed that recalling without entering the capsule left
the dock visible: the input mask excluded the gap, so no hover enter/leave reached
the controller. The input region now joins the capsule to the physical edge and
includes the empty edge strip across the full recall span. Collision remains the
rounded capsule only; glow remains clipped to the capsule.

Regression geometry checks cover all four edges, gaps of 0/8/30 px, outer corners,
recall span ends, canvas bounds and collision exclusion. Local build and all seven
CTest entries pass. Real KWin re-hide after edge-only entry/exit still requires
maintainer confirmation; no compositor success is inferred from these tests.

## Settings and launcher validation — 2026-11-13

The maintainer confirmed the edge corridor fix and merged PR #1. New automated
coverage adds INI round trips, defaults, input sanitation, ordered launcher saving
and removal, memory-only demo isolation, settings-window QML loading, and a native
KDE TasksModel test using temporary desktop entries (no applications are launched).
A software screenshot of the configuration window was inspected for control layout.
These checks do not validate native popup focus or KWin output switching.

Manual acceptance for this stage:

- Right-click the empty capsule and each task; menu positions correctly on all edges.
- Configure opens a normal window with working keyboard, Apply and Close; dock stays
  available while settings/menu are open. Quit terminates the process.
- Apply spacing 0/8/30/128, radius 0/10, zoom and icon size; collision remains capsule
  only and magnification/edge recall remain correct.
- Change edge/output while visible and previously hidden; no stale edge registration
  or duplicate dock. Disconnect the chosen output and inspect primary fallback.
- Pin a running app, close/reopen it, unpin while running and while stopped; inspect
  positions and persistence. Open two windows from the same app (still ungrouped).
- Reorder pins with Up/Down, remove, add an installed desktop entry by ID; restart
  without CLI overrides and verify saved state/order.
- Demo settings/pins must not overwrite the real settings file.
- Retest settings under Qt 6.12/CachyOS and genuine Wayland rendering.

Local result: all nine CTest entries pass with Qt 6.8.2. The QML suite includes
12 checks including setup/cleanup, Apply/discard behavior and right-click opening.
The native launcher fixture exercises identity/list/order APIs, not visible task
rows: the offscreen window backend leaves the concatenated task model without
usable display columns. Window replacement and visible ordering remain manual
Wayland checks. The platform also reports unsupported popup keyboard grabs.

Zero-spacing regression: the input strip retains one logical pixel across the
full recall span even when the capsule touches the edge. Otherwise a recall
beyond its shorter length could again miss pointer entry. All-edge tests now
check the recall ends at zero gap as well. This does not enlarge dodge geometry.

## Breeze settings startup follow-up

CachyOS reported implicitWidth binding loops in the two Breeze ComboBoxes. The
settings form now supplies an explicit font-scaled preferred width, independent
of the style content item's available width. The UI test checks stable preferred
widths at different window sizes. Local tests use Fusion; the maintainer's Breeze
version still requires confirmation.

QML warnings were also incorrectly treated as fatal startup errors. Normal runs
now keep logging warnings without terminating a successfully loaded interface.
Missing/invalid QML roots remain fatal. Smoke tests still fail on any QML warning,
so this runtime robustness change does not hide warnings from validation.

## Menu anchoring and live reordering

Maintainer desktop feedback: the context menu appeared away from the click and
settings reordering did not immediately update the dock. Menus now have an
explicit dock-root parent, negative margins (allowing the popup window outside
the narrow host), and an edge-aware position beside the visible dock/icon bounds
aligned to the click. KWin retains final popup constraint handling at screen edges.

LiveTasks observes the settings QObject directly instead of waiting for host
context-map replacement. External launcher-list changes also rebuild KDE's manual
sort map; changing the saved list alone is not a visible-row move. The native test
now changes order on the existing model rather than recreating it.

Drag reordering uses a root DragHandler with the platform threshold, TasksModel.move
and syncLaunchers on release. Zoom pauses during dragging to stabilize targets.
A temporary inert model tests the full gesture, a changed row order, one save, and
no activation; the test explicitly waits for Row layout after replacing its model.
This is distinct from live KDE window/launcher testing. Placement calculations
cover all four edges and different click positions.

Manual: test right-click near both ends of each dock edge, magnified icons, screen
corners and HiDPI; test immediate Up/Down, drag running/stopped pinned apps, close/
reopen apps, restart persistence, drag cancellation and long overflowing task lists.
Actual KWin popup placement and native visible row movement require confirmation.

## Native Wayland anchoring and desktop identity follow-up

Maintainer confirmed the previous reorder/drag fixes work, but the menu still
opened at a fixed bottom-left position. The previous placement calculation tests
did not exercise Qt Wayland's parent-control positioner. They are retained as
fallback geometry tests, not evidence of compositor placement.

New checks: native QWindow surface creation applies parent-local anchor/gravity
for all four edges; reuse updates the click; destroy/recreate retains the latest
anchor; out-of-bounds anchors clamp inside the host; unrelated settings popups
remain untouched. QML tests cover four-edge anchor points and existing menu
opening, drag, settings and hover behavior. Qt 6.8.2 build and all nine CTest
entries pass. No live KWin session is available here.

The portal warning has a reproducible contributing mechanism: with PATH limited
to /usr/bin:/bin, GLib rejects an entry with Exec=plasma-next-dock and accepts the
same entry with a quoted absolute executable path (including a directory with
spaces). Isolated installation verifies --prefix overrides, quoted Exec and no
DESTDIR leakage. CI also checks the installed /usr/bin Exec. QML parsing, shell
syntax and git diff whitespace checks pass.

Manual acceptance on CachyOS: stop the dock, update this branch, run ./install.sh,
and launch ~/.local/bin/plasma-next-dock. Check the portal warning is absent;
right-click at different heights on the left/right and different horizontal
positions on top/bottom. Check screen ends, HiDPI, closing outside/Escape,
reopening, Pin/Unpin and Configure, output/edge changes and re-hide after closing.
The two desktop outcomes remain pending maintainer confirmation. Do not describe
synthetic positioner tests as successful visual Wayland testing.

## Adaptive sizing — 2026-11-14

Maintainer accepted the final PR #2 menu/portal fixes and merged them. This is the
baseline for the new sizing branch; earlier pending notes above are historical.

Added tests sweep 0–100 tasks, preferred sizes 24/40/96 and zoom 1/1.5/2.5,
checking monotonic reduction, minimum/preferred limits, canvas bounds and the
local-zoom width budget before overflow. Tiny output geometry and scroll clamping
are included. A rendered offscreen QML fixture grows from 5 to 22 to 80 tasks,
checks reduced capsule thickness and magnification, wheels the overflowing strip,
reaches the last icon, removes extra tasks, and verifies recovery and unchanged
preferred size. Existing hover, drag, menu, settings, collision and four-edge
smoke coverage remains enabled. All nine local CTest entries pass (Qt 6.8.2).

Manual CachyOS acceptance: on each edge, add/remove enough pinned/running apps to
trigger reduction; try 40 px / 1.5x and 96 px / 2.5x, rapid hover across the strip,
then enough apps to reach minimum size and scroll to both ends. Check native
reordering and popup alignment after scrolling; change output/resolution/scaling,
check restoration after closing apps and unchanged settings after restart. Verify
capsule-only dodge and edge recall. Fractional scaling, actual KWin resizing and
GPU animation smoothness are not proven by offscreen tests. No visual Wayland
success is claimed for this new stage.

### Premature shrinking correction

Maintainer reported that the initial implementation shrank the dock immediately
and appeared unable to shrink further. Reserving full zoom for every slot inflated
the width budget and reached the minimum prematurely. Replace it with resting
width plus at most two zoom equivalents. Regression: 18 icons at 40 px/1.5x on
984 px keep 40 px; 22 reduce but remain above 24 px; 80 use minimum-size overflow.
The animation-tail test explicitly exceeds the aggregate budget and checks its
bounded rendered weight. All nine CTest entries pass after the correction; staged
installation and QML checks pass. Live CachyOS confirmation remains pending.

### Wheel input follow-up

The maintainer accepted adaptive shrinking/growing but reported no wheel scrolling.
The prior QtTest mouseWheel coverage used unsynthesized vertical events only.
A new test sending QWheelEvent with MouseEventSynthesizedBySystem failed before
this fix: WheelHandler's default device filter rejects synthesized wheel events.
This is a verified input-path defect, not proof of the maintainer's exact device
source (no live input trace is available). Pure horizontal gestures were also
filtered by the default vertical orientation before reaching our callback.

Two fixed-root handlers explicitly accept Mouse and TouchPad, route vertical or
horizontal input once per event, prefer pixel deltas, and disable while a menu is
open or no content overflows. Tests now cover synthesized angle/pixel input,
horizontal/vertical/diagonal deltas and reversal on all four edges, plus ordinary
wheel events before and after scrolling beyond a viewport. All nine CTest entries
pass after the fix, including the previously failing synthesized event. Build,
QML parsing and staged installation pass. No sizing formula was changed.

Manual: with enough tasks to overflow at minimum size, wheel over an icon and in
the screen-edge corridor; reach both ends on each dock edge. Check mouse and
trackpad, reverse direction, menu-open behavior, hover and drag. At maximum dock
length but with every icon still fitting, there is intentionally nothing to scroll.
Actual CachyOS input behavior remains pending maintainer confirmation.

## Native context menus — 2026-11-14

Maintainer acceptance: PR #3 adaptive size recovery and overflow wheel scrolling
confirmed working and merged. These remain regression requirements.

Local environment: Qt 6.8.2 / Frameworks 6.13 / Plasma 6.3.6 extracted libraries,
offscreen Qt with software Qt Quick rendering, no KWin compositor. Ten CTest
entries pass, including the original nine checks and native-application-menus.
The Quick suite also includes actual PlasmaExtras/QMenu construction and activation.

Completed checks:

- KService resolves real fixture desktop files and applications: URLs, excludes
  hidden desktop actions and preserves labels/icons; no KDE backend shortcuts.
- KIO actually launches a harmless argument-recording executable: private action,
  profile argument containing spaces, a local Place containing spaces, and a remote
  sftp URL arrive as the expected individual arguments. No network contact occurs.
- KFilePlacesModel custom/hidden bookmarks, group submenu, and More Places action.
- KDE privacy disabled/blocked applications yield no recent section. A populated
  live activity history is not available here, so recent retrieval/Forget remains manual.
- Actual native QMenu labels and Pin/Unpin callbacks, missing-action empty sections,
  background Configure/Quit, window menu structure, disappearing model targets.
- Persistent target survives removal of an earlier row and never targets its
  replacement. Widget popup late transient-parent assignment retains native anchor.
- Project French menu labels and installed KDE French heading lookup. GNU gettext
  needs a non-C locale; this check explicitly skips on machines lacking one. The
  KDE-catalog check skips if its French catalog is absent. Both ran locally.
- Existing sizing, synthetic wheel/trackpad, dragging, zoom, hover, settings,
  launcher persistence, geometry/dodge, four-edge QML and live-model smoke checks.
- QML parser checks, shell syntax, git diff whitespace check; staged installation
  installs executable, absolute-Exec desktop entry and French MO catalog under the
  requested prefix. No installation into system directories or Plasma restart.

Expected headless warnings: no KWin/Activity Manager/UDisks service, no real recent
history, offscreen keyboard grabs/raise unsupported, no Kirigami Fusion platform
plugin. Tests do not claim native popup grabs, translucency or Wayland placement.

### CachyOS acceptance checklist

Quit the previous Plasma Next Dock instance through its menu before starting the
new installed executable. Use ./install.sh; no Plasma Shell restart is required.

1. On a French session compare Firefox's menu with Icons-Only Task Manager:
   section headings, application-provided actions, private/profile launch actions
   when supplied by the actual desktop entry, and absence of empty headings.
2. Compare the native menu style, shadows/corners and theme-provided translucency.
   Do not add forced opacity as a workaround. Record widget style/platform theme
   if the two menus differ; the old plasmoid already used PlasmaExtras too.
3. Dolphin: actual custom Places, hidden bookmarks, other groups/submenus, More
   Places, a local folder containing spaces, and a usable remote URL.
4. Recent files: only current application/activity history; open a recent file,
   Forget, and KDE's no-history/blocked-application settings. Empty history is valid.
5. Running window: close, move/resize, minimize/maximize, fullscreen, above/below,
   shade if supported; multiple desktops/activities and output movement if offered.
6. Supported media player: previous, play/pause, next, stop, restore/quit. Exit the
   app while its menu is open; a removed task must close without affecting another.
7. Pin/unpin running or closed applications, restart the dock, check saved order;
   Configure and Quit from both an application and the empty capsule.
8. Bottom/top/left/right: menu near the click and facing inward, nested menus,
   keyboard arrows/Escape, click outside, screen corners and fractional scaling.
9. After closing a menu, hover/zoom/glow, drag reorder, wheel scrolling, adaptive
   shrink/recovery, capsule-only dodge and edge recall still work normally.

This stage is not yet complete feature parity with a grouped Plasma task manager:
window grouping/previews, per-stream volume controls, bounce and blur remain future
stages, as documented in the roadmap.

### PR #4 desktop acceptance and CI catalog compatibility

The maintainer reports the native menus working correctly on CachyOS/Plasma 6.8.
The first GitHub CI run compiled successfully but failed the French heading check:
Debian's Plasma 6.3 catalog translates `Recent Files` without a msgctxt, whereas
current KDE uses `@title:group for section of menu items`. The prior local catalog
was the current KDE one, so it had not exposed this older-catalog mismatch.

Heading lookup now prefers the contextual entry and falls back to the legacy
context-free entry only when necessary. The translation assertion remains enabled.
The complete ten-entry suite passes with both current and Plasma 6.3.6 French
catalogs. This preserves the desktop-validated current behavior. No menu styling,
geometry, window actions or compositor configuration changes are involved.

## Grouped-window preview stage — 2026-11-14

Native context menu PR #4 was accepted and merged. The new preview stage passes
all **11 CTest entries** with Qt 6.8.2 / Plasma 6.3.6 in the isolated environment.
Additional coverage includes:

- Group children, single windows and empty launchers; title/UUID/state updates.
- Persistent indexes across child/root insertion and removal, source destruction,
  non-closable windows and stale-action rejection before queued model refresh.
- Real Plasma ToolTipArea import, explicit location on all four edges, showing
  and switching its shared owner/name, and dismissal/model release.
- Populated QML preview cards routing activate/close to the intended child.
- Real KPipeWire/ScreencastingRequest component loading with no capture UUID.
- Separate actual native grouped presentation and ungrouped collision models.
- Existing pointer, sizing, scrolling, launcher ordering, settings and menu tests.

Compilation, QML parser checks, shell syntax, git diff whitespace and isolated
installation checks pass. The installed desktop entry retains absolute Exec and
now advertises the screencast interface. No system installation is performed.
The source baseline for this stage is main a39bc3f7b6734bd95733c106e7d224c8acf5b6ee.

No live KWin session is available here. Inward physical placement, live thumbnails,
real-window activation/close, crossing into an interactive tooltip, grouped drag,
GPU load and multi-output scaling require the checklist in window-previews.md.
Explicit location assertions are not proof of the final on-screen coordinates.

## PR #5 positioning feedback

The maintainer reports the preview feature functioning but supplies a recording
showing substantial placement offsets. Correct edge properties did not prove
correct global coordinates: Qt's normalized top-level origin was being used by
native Plasma tooltip placement. See window-previews.md for the verified code path.

The origin adapter adds a twelfth CTest entry. It simulates backend normalization
and tests all four edges, translated/negative output origins, mapToGlobal, unchanged
surface size, updated origins and native surface recreation. The full 12-entry
suite passes locally; compilation and isolated installation pass. No live KWin
positioning is claimed. Recheck tooltips and previews near each icon, transitions,
magnification, adaptive resize, menus, dragging and dodge on the actual desktop.

## Advanced indicators and reveal stage — 2026-11-14

The maintainer accepted corrected preview positioning and merged PR #5. New local
checks retain all 12 CTest entries and expand the Quick suite to 47 passing cases.
They cover all three modes, configuration controls/defaults, native SVG elements,
all four custom edges, count/overflow folding, state dimensions, separate unfocused
color, opacity/desaturation, bounded model reads and stable segment objects during
hover/zoom. INI tests cover mode switching, custom values, invalid input and the
reveal toggle. Settings tests cover Apply/discard and persistence of indicator edits.

Compilation, QML parsing, PO catalog validation and isolated installation pass.
Native reveal uses KDE's documented slide effect; no live KWin compositor is
available here. Do not describe smooth recall, reversal, theme fidelity or GPU
performance as visually validated. Use the checklist in indicators.md on CachyOS.

## Indicator anchor regression — 2026-11-14

A new Main.qml integration test samples intermediate magnification and shrink
frames for native Plasma strips and Custom segments on all four edges (eight
data rows). It checks fixed cross-axis coordinates while confirming icon growth.
Running it against the previous Main.qml reproduces exactly two failures:
Custom bottom and right. The corrected resting lane passes all eight rows.
Fractional anchor alignment also prevents subpixel jitter on vertical layouts.

All 12 CTest entries pass with the correction, including 57 Qt Quick cases.
Compilation, QML parsing, shell syntax, whitespace and staged installation pass.
These offscreen tests verify animated geometry, not live KWin rendering. Confirm
bottom/right magnification visually on CachyOS before merging. No settings were
removed; cleanup remains deferred.

## Capsule backgrounds — 2026-11-14

All 13 CTest entries pass locally, including 64 Qt Quick cases. The new native
background-effects test records production effect requests on real offscreen
QQuickWindows: rounded/fractional bounds, radius-only edits including zero and
clamping, parameter updates, no writes for changing icon input geometry, empty
regions, repeated palette/visibility cycles, deferred work during surface teardown,
recreation and destruction with pending work. Calls are checked on the GUI thread.
QML cases cover all five modes, shared glow/background radius and Transparent
suppression; settings tests cover Apply/reopen, persistence, defaults and invalid
values. Existing indicator anchoring, menus, previews and adaptive-layout tests pass.

Build, QML parser, French gettext catalog, shell syntax, whitespace and staged
installation checks pass. No new package dependency or installer changes are needed.
There is no live KWin compositor here. These results do not validate actual blur,
contrast, slide animation, wallpaper transitions or GPU appearance. Follow the
CachyOS checklist in backgrounds.md before merging.

## Border and layout refinement — 2026-11-15

The full 13-entry CTest suite passes, including 65 Qt Quick cases. New coverage
checks independent (unequal) icon/end/thickness spacing and zero values on all four
edges using actual Main.qml icon/capsule coordinates. Adaptive budget checks cover
large padding/spacing combinations; previous shrink/recovery, overflow scroll and
indicator anchoring tests remain green. Border checks cover zero width and custom
color; settings tests cover persistence, Apply/reopen, ranges and ignored obsolete
blur-tuning keys. The native blur lifecycle suite still passes after removing
contrast registration.

Compilation, QML parsing, gettext validation, whitespace and staged installation
pass. Confirm contour appearance, large/zero padding, hover and dodge on CachyOS;
these offscreen checks do not establish compositor pixel rendering.

## Magnification reach and hover lift — 2026-11-15

All 13 CTest suites pass, including 66 Qt Quick cases. Falloff tests sample fractional
pointer positions at every radius 0–8 and check the shared maximum-weight budget.
Large lift/radius combinations stay inside output budgets. Actual Main.qml zoom
tests now use 24 px lift, checking inward displacement, canvas containment and
stationary Plasma/Custom indicators on all four edges throughout animation.
Settings tests cover defaults, persistence, clamping and Apply/reopen for both
controls. Fixture creation now checks QFile::open instead of ignoring its return.
QML parsing, gettext, whitespace and staged installation pass. Live Wayland
appearance, pointer travel and previews still require desktop confirmation.

## Application status stage

Local build: Qt 6.8.2, Plasma 6.3 installed QML modules. Thirteen regular CTest
entries pass offscreen. Added coverage includes grouped child PID matching, portal
ID priority, mute toggling across streams, relative volume, speaker clicks,
MPRIS capability/button routing, disabled preview cards, and persistence of all
six settings through the settings UI and file reload.

The fourteenth entry, native-application-status, runs a real installed KDE
SmartLauncherItem with a temporary desktop-entry cache and an isolated D-Bus bus.
This runner forbids socket creation, so dbus-run-session fails before the test;
CI is responsible for that round trip. Direct loading of native SmartLauncherItem
and the plasma-pa model succeeds locally. No live audio operation, PipeWire server,
KWin screenshot or actual user media player has been validated here.

Staged installation, shell syntax, translation compilation and git diff whitespace
checks pass. See application-status.md for the CachyOS manual acceptance checklist.

### CI follow-up

GitHub's isolated bus confirmed delivery of the real native launcher count (7),
visibility and progress (42%). The first run then exposed a test lifetime error:
tryCompare captured the old SmartLauncherItem before the queued launcher change
replaced it. Wait for replacement before observing the new item's zero/hidden
state. Also cover explicit group selection while a title tooltip is already open,
and retain compact tooltips for tasks without media. Full CI is rerun after this
correction; real desktop acceptance remains required.

### CachyOS resource-loading follow-up

The maintainer's Qt 6.12 run could not load any embedded QML in hoverqmltest,
while the executable's smoke tests passed. Both targets previously generated
resources with the same `dockqml` name/output paths. Give the test bundle its own
`docktestqml` name, explicit source base, and explicit Q_INIT_RESOURCE reference.
Validate every packaged QML/JS file before entering QuickTest so packaging failures
produce one actionable error rather than a cascade of null-component failures.
The exact Qt 6.12 failure is not reproduced on the local Qt 6.8 runner; confirmation
on CachyOS is required. Do not claim all Qt versions have been tested.

A typed Plasma ToolTipArea reference now clears when its owner is destroyed;
dismissal checks the method before calling it. A regression test destroys an owner
and dismisses the remaining preview. This protects the separate stale-tooltip
error observed in the existing installed executable.

The installer intentionally stops on failed tests, before cmake --install. Missing
new audio UI after this failure can therefore be the previous installed binary.
Update the branch and rerun ./install.sh; do not bypass tests. Quit/restart only
Plasma Next Dock after successful installation. Audio matching still needs actual
desktop validation once the new binary is installed.

### Modern applet loading follow-up

The maintainer confirms the resource fix: hover-and-render now passes on Qt 6.12.
The remaining failure is native SmartLauncher loading. Modern Plasma's applet
library registers a QT_NO_PLUGIN QML module only when loaded by the host; importing
its URI alone was insufficient in this standalone host. Load the installed applet
library without instantiating its factory, with the legacy import retained.
New applet-status-loading regression uses a NO_PLUGIN QML module fixture whose
factory must never be constructed. See application-status.md for the distinction
between this mechanism test and actual installed-KDE integration/desktop tests.

### Task removal during deferred status updates

The maintainer accepted the audio/status functionality on CachyOS, but reported
repeated TaskStatus.qml IsWindow-of-null errors when opening/closing windows.
TasksModel can detach a delegate while Qt.callLater(refresh) is queued. Guard the
missing task, clear its audio/player state, and make the launcher URL binding
null-safe. A warning-sensitive test covers initially null tasks and repeated
attach/queued-update/detach cycles, then verifies recovery on reattachment.
The separate startup Unity/JobViewServer registration warnings are emitted by KDE
services and are not suppressed by this fix.

## Behavior and separator — 2026-11-15

Base: merged PR #8; branch feature/behavior-and-separator. Added native TasksModel
binding tests (group/sort/filter, selected output with negative origin, collision
independence, launcher reorder retaining sort binding), settings persistence and
invalid enum fallback, settings draft safety, action-policy dispatch/wrap/minimized
filtering, separator geometry on four edges and both directions, dynamic pin state,
magnification lane stability and controller attention inhibition.

Local environment: Qt 6.8.2 / Plasma 6.3, offscreen/software. The native application
status D-Bus test cannot start here: dbus-daemon reports `Failed to open socket:
Operation not permitted`. This is not recorded as a pass; the complete test remains
mandatory in GitHub CI and on CachyOS. No tests have been disabled or weakened.
Installation was staged under /tmp (executable, desktop entry and French catalog),
with shell syntax and git diff whitespace checks. The new code adds no dependencies.
See behavior.md for live desktop acceptance; native window action effects, multi-
monitor filters and compositor attention reveal require CachyOS validation.

Result: all 14 locally runnable CTest entries passed (27.03 s), including the
expanded hover/render suite. Native application status remains the separate
runner limitation above; full CI result is reported on the pull request.

### Qt 6.12 launcher fixture isolation follow-up

CachyOS reported one failure: NativeLaunchers.test_pinUnpinAndRestoreOrder found
launcherCount=1 instead of 0 immediately after test_behaviorFiltersAndSort. All
other cases passed, including the installed native audio/status integration.

The preceding test saved a QVariantMap with Object.assign, which does not detach
nested QML sequence references. That is unsafe as a restoration snapshot on newer
Qt (QVariantMap in-place QML support was extended in Qt 6.9). This matches the one
launcher introduced by that test surviving restoration. The fixture now snapshots
its JSON-compatible settings deeply, asserts that the saved list remains empty
after pinning, waits for the native launcherList to match the restored list, and
drains deferred destruction before another test creates a model. Pin/unpin also
restores its fixture in finally, including on assertion failure.

No production settings, native pinning behavior or assertions are removed. Theme,
shadow and activity-database warnings arise in the isolated offscreen fixture and
are distinct from this assertion. Do not change the maintainer's theme/database.
Reference: https://doc.qt.io/qt-6/qtqml-cppintegration-data.html
Local validation uses Qt 6.8.2; the exact Qt 6.12 failure needs maintainer recheck.
The focused NativeLaunchers suite passes, and all 14 locally runnable CTest entries
pass after the fixture fix (27.37 s). The unchanged native status test was confirmed
passing in the maintainer's supplied Qt 6.12 log. No Qt 6.12 local pass is claimed.

### Discrete wheel cycling — desktop follow-up

The maintainer confirmed the launcher-fixture correction, then reported that group
cycling needed three wheel notches. The implementation accumulated angle deltas
until 120, incorrectly coupling a discrete window action to wheel magnitude.
Each nonzero angular wheel event now selects one adjacent window immediately;
continuous pixel input keeps its 40-pixel threshold and discards an opposite-direction
remainder. The actual-overflow branch is unchanged and still takes priority.

Regression coverage includes angular magnitudes 15/40/60/120/240 in both directions,
zero input, continuous pixel accumulation and direction changes. Existing four-edge
synthesized/diagonal overflow tests remain enabled. Real wheel feel on CachyOS still
requires maintainer confirmation; this runner uses Qt 6.8.2 offscreen.
Result: build, all 14 locally runnable CTest entries (28.09 s), staged installation
and whitespace validation pass. Native D-Bus test remains the runner limitation
already documented above; no test is disabled in CI or the installation script.

### Pixel/combined wheel input follow-up

The maintainer still reports 2–3 notches after the first wheel change. That change
only removed the threshold for angle-only events: nonzero pixelDelta still selected
the accumulated path, including events carrying both kinds of delta. No raw event
capture from the maintainer is available, so this is the remaining code-path defect,
not a claim about the exact device's event payload.

Remove distance accumulation from window selection entirely. Each nonzero angular,
pixel-only or combined event requests one adjacent window; zero events do nothing.
Overflow continues using its existing distance-based scrolling path. Regressions
now cover all three event forms with small and large magnitudes in both directions;
the previous tests covered angle-only and deliberately retained pixel accumulation.
Desktop wheel behavior remains to be rechecked, including continuous touchpads.
Validation: build and all 14 locally runnable CTest entries pass (26.83 s, Qt 6.8.2
software/offscreen). Native D-Bus test has the same documented runner restriction.

## Icon bounce — 2026-11-15

Base: accepted/merged PR #9; feature/icon-bounce. Added focused animation lifecycle
checks (finite completion, repeated attention, clearing attention, disabling,
startup and suppression), four-edge inward bounds under simultaneous 48 px bounce,
zoom and 32 px lift, unchanged capsule/indicator coordinates, tiny-output fitting,
settings persistence/validation/draft handling and native menu test-action dispatch.

Build and all 14 locally runnable CTest entries pass (30.60 s, Qt 6.8.2 / Plasma 6.3,
offscreen/software). Staged executable, desktop entry and French catalog install
successfully; shell syntax and whitespace checks pass. The native D-Bus test still
cannot start in this runner (`Failed to open socket: Operation not permitted`);
it remains enabled in CI and ./install.sh. No Qt 6.12 or live KWin result is claimed.
See bounce.md for the CachyOS acceptance checklist, particularly real launch/attention
notifications, interaction feel, popup placement and hide/reveal behavior.

## Stable bounce interaction — 2026-11-16

PR #10 feedback: clicks were bound to moving icon bounds and the native input mask
followed those bounds, allowing animation to remove the cursor from the surface.
Use stable task lanes through to the physical edge. Coalesce transient row counts
before canvas resizing, and recover finite launch feedback by service URL after
launcher/startup/window delegate replacement.

Added synthetic edge primary/middle clicks on four edges and both directions,
stationary-pointer magnification during bounce, unchanged input bounds during
animation, synchronous delegate replacement with no canvas resize, and correct
launch identity (no bounce on a neighboring row). Existing drag, menu, audio/status,
preview, separator, adaptive layout and rendering tests remain enabled.

Build and all 14 locally runnable CTest entries pass (42.59 s, Qt 6.8.2 / Plasma 6.3,
offscreen/software). No TypeError/ReferenceError in the final test log. Staged
installation, shell syntax and whitespace checks pass. The native D-Bus test is
excluded locally due to the previously documented socket restriction, not disabled
in the project. Tests are synthetic; actual Wayland input-region behavior and the
maintainer's live launcher transition still require the checks in bounce.md.

## Residual zoom during bounce — 2026-11-16

The maintainer accepted edge clicks but isolated a remaining zoom dip to the
outward edge of a moving icon crossing the cursor; clicks further outward at the
indicator/physical edge did not reproduce it. Initial launcher replacement also
briefly shrank the icon. Earlier edge-lane tests did not cover that crossing.

Add a four-edge test with a stationary cursor initially inside the icon, middle
click, verified icon/cursor crossing, stable logical pointer and retained zoom,
followed by genuine departure/resting-size recovery. Replacement tests now check
the zoom factor immediately, rather than after a settling delay. Native controller
tests cover window-level pointer events, ignored child hover/repeated positions,
true departure, transparent margins, fractional edge coordinates and detachment.

Build and all 14 locally runnable CTest entries pass (48.96 s, Qt 6.8.2 / Plasma 6.3,
offscreen/software). No TypeError/ReferenceError in the final test log. Staged
installation, shell syntax and whitespace checks pass. Native D-Bus coverage retains
the previously documented local restriction and remains enabled in CI. These tests
do not constitute Qt 6.12/KWin desktop acceptance: recheck the maintainer's exact
first-launch and low-on-icon middle-click scenarios, plus menus/audio/preview/glow.

## First-window identity anchor — 2026-11-16

Added a failing-before/passing-after test for a stationary hovered application
moving between model rows during launch: before correction, 60 px became 46.8 px.
The combined move/replacement case returned at 49.2 px instead of 60 px even after
queued reconciliation. Retaining service identity/fraction and initializing the
replacement at the reconciled anchor fixes both synthetic cases. The test checks
that genuine pointer movement still selects a new application normally.

Build and all 14 locally runnable CTest entries pass (51.47 s, Qt 6.8.2 / Plasma 6.3,
offscreen/software). Staged installation, shell syntax and whitespace checks pass.
Native D-Bus coverage retains the previously documented local restriction. The
maintainer has accepted the previous pointer/click fixes; the exact first-window
transition on CachyOS/Qt 6.12 still needs rechecking. No live KWin result is claimed.

## TaskStatus context teardown — 2026-11-16

The maintainer accepted the bounce/zoom behavior and reported runtime diagnostics.
A new fixture creates TaskStatus in a child QQmlContext, deletes the context before
queued initialization and defers object destruction. Against the previous QML it
reproduces the exact `TaskStatus.qml:66: ReferenceError: statusSupport is not defined`
warning; failOnWarning makes the regression fail. With owned single-shot queues,
five successive teardown cases pass without ReferenceError/TypeError.

Build and all 14 locally runnable CTest entries pass (58.88 s, Qt 6.8.2 / Plasma 6.3,
offscreen/software). Staged installation, shell syntax and whitespace checks pass.
The native D-Bus test retains the documented runner restriction and remains enabled
in CI. KDE Unity/JobViewServer ownership warnings are documented separately in
application-status.md and are not suppressed. Real desktop diagnostic confirmation
is still left to the maintainer.

## Hover highlight and indicator polish (icon-bounce branch)

Added automated checks for default-on/persistent icon hover highlighting, immediate
disable/re-enable while hovered, inward native frame expansion on all four edges
with a fixed outward edge, and active indicator palette selection inside an
inactive parent. Existing inactive opacity/color tests remain unchanged.

The isolated Indicators-only invocation does not initialize the Plasma theme
through Main and fails the existing group-symbol natural-size check in this runner;
the complete hover-and-render suite is the authoritative themed integration run.
No production check was weakened. The hover toggle test explicitly restores the
bottom edge/direction before pointer synthesis to avoid prior test geometry.

Manual acceptance on CachyOS:

- In every indicator mode, hover icons, toggle Highlight icons on hover off/on,
  and restart the dock to verify persistence. Repeat during zoom and bounce.
- In Plasma mode, verify the task background stays visible behind magnified/lifted
  icons on all edges; the outward indicator edge must remain stationary.
- In Custom mode, compare the focused task's accent with the active preview
  segment. Inactive opacity, custom unfocused color and minimized desaturation
  must continue to work. Change the system accent and repeat.
- Check the user's theme, HiDPI, tooltips, native menus, edge clicks and hide/reveal.
  Offscreen tests do not validate these live compositor/theme combinations.

Validation result: build and all 14 locally runnable CTest entries passed in
54.26 seconds (Qt 6.8.2 / Plasma 6.3, offscreen/software). No TypeError or
ReferenceError in the final log. Staged installation, install.sh syntax and
whitespace checks passed. Native application-status remains enabled in the
project/CI but excluded locally because this runner prohibits D-Bus sockets.

### Hover delivery and accent follow-up

The new test_hoverAcrossIconAndTooltip fails with the preceding implementation:
icon.active becomes false when the synthesized pointer crosses from the edge lane
onto the icon's ToolTipArea. It passes after the fix on all four edges and checks
both native frame hover and icon highlighting. The palette regression also verifies
that an ancestor's dark Kirigami highlight cannot change the Custom renderer's
explicit active SystemPalette accent, and that dock/preview colors match.

Manual check: cross slowly from the edge lane through the bottom/middle/top of an
icon, allow its tooltip to appear, and move to neighboring icons. The highlight and
Plasma hover frame should remain active on the current task. Compare the Custom
active indicator with the configuration preview, including an accent change.

Follow-up validation: build, all 14 locally runnable CTest entries (53.94 seconds),
staged installation, shell syntax and whitespace checks passed. D-Bus exclusion
and live Wayland/theme limitations remain as documented above.

## External drops and application chooser

Added isolated installed-application fixtures, searchable chooser coverage, canonical
alias deduplication, native launcher insertion/persistence, insertion geometry on all
four edges in both directions, document routing, deferred activation/invalidation/
cancellation and synthetic native Qt drag enter/move/drop/leave delivery. No test
launches the maintainer's applications or writes their settings.

An existing bounce test sampled unfinished zoom under load; it now waits for the
zoom factors to settle before asserting bounce-only stationarity. The original
geometry assertions remain intact. Intermediate full runs also encountered timing
failures in old launch-animation tests; the isolated bounce suite passed. Record
CI and actual Wayland validation separately from synthetic event acceptance.

Remaining desktop checks are in external-drops.md. In particular, synthetic Qt drag
events cannot prove cross-process Wayland serials/permissions or that an application
accepts every supplied document type. Native application-status still requires the
CI/user D-Bus session unavailable in this runner.

Final local result: clean build, 14/14 runnable CTest entries passed in 57.05 s
(Qt 6.8.2 / Plasma 6.3, offscreen/software), staged installation and shell/whitespace
checks passed. The native D-Bus status test remains enabled for CI and the user.

### External-drop desktop acceptance — 2026-11-19

The maintainer confirms all delivered functions work as expected after several days
on CachyOS Wayland with no detected problems. GitHub Actions run 43819877812 completed
successfully for 6dcf3dabf2b44af5b3c1fee0b2137832eb8c1816. Final PR preparation only
updates README/development notes; the tested implementation is unchanged. This
acceptance does not independently certify every item in the extended output/source
matrix. Keep that matrix for future regressions. No automatic merge performed.

## Initial launcher layout on KWin (2026-11-19)

With Dolphin, Firefox, Konsole and Visual Studio Code pinned on the left, the
original executable requested a 99 × 200 logical-pixel surface before updating
its request to 99 × 254. After initializing the task count and divider during
component completion, the first layer-shell request and KWin configure both
measured 99 × 254. A live capture on CachyOS showed the complete fourth icon and
the rounded end of the capsule. The adaptive layout regression test reads the
task count immediately after loading, before queued model changes can settle.

## Optional login startup (2026-11-19)

On CachyOS Plasma Wayland, the French checkbox was initially clear. With an
isolated XDG configuration copied from the four-launcher setup, checking it and
applying created the user symlink. Reopening the dock with the same configuration
showed the checked state. A second login invocation exited successfully and left
the original PID holding the runtime lock. Clearing the checkbox and applying
removed the link. The regular dock was then restored with all four launchers.

In a temporary prefix containing spaces, desktop-file-validate accepted the login
template. The systemd XDG autostart generator produced one matching user service
while enabled. Reinstalling retained the link. Uninstall removed it and running
the generator again produced no matching service. The settings-persistence test
also covers missing templates, conflicting files, repeated enable/disable, and
demo isolation. All 15 CTest entries passed. An actual KDE logout/login cycle
with the option enabled and then disabled remains a manual acceptance check.

## Multiple docks and outputs (2026-11-19)

On the single-output CachyOS VM, a temporary copy of the existing configuration
opened as Dock 1 with the original four pinned applications. In the French
settings window, Add dock selected Dock 2 with fresh settings. Changing its edge
to Right and applying preserved Dock 1 on Left. After restarting, both profiles
were restored. Selecting Dock 2 displayed its saved Right edge. Both surfaces
were visible on the same monitor with distinct launcher sets. Confirming removal
of Dock 2 left only Dock 1 and its original launchers in the INI file.

All 15 CTest entries passed. The settings test covers legacy migration,
independent values and launchers, output assignment, disconnection and fallback,
restoration, conflict detection and removal of the original profile. The prior
single-dock autostart release was also confirmed by the maintainer on a KDE
login configured to start an empty session.

The maintainer validated the full multi-monitor checklist on CachyOS with Samsung
and AOC displays, including different scale factors, independent settings,
restart, disconnect/reconnect, edge recall and preview placement.

## Dragging a document to a grouped window (2026-11-19)

On the CachyOS VM with a left-edge dock, two Dolphin windows showed separate
temporary directories. Dragging a file from the first window onto the Dolphin
group opened both previews. Dwelling on the second preview raised the destination
window while keeping both previews visible. With the same drag still held,
hovering the first card and then the second raised each corresponding window.
Leaving the panel closed it, and releasing with Ctrl in the destination copied the file. Both the original and
the destination copy were verified on disk.

## External drag scrolling on an overflowing dock (2026-11-19)

On the CachyOS Wayland VM, grouping was disabled in the Behavior settings of a
temporary configuration. One Qt application opened 48 real windows with numbered
icons. The vertical dock overflowed. During a native file drag, holding the
pointer at the lower end revealed window 48. Holding it at the upper end scrolled
back. Moving into the middle stopped scrolling and dwelling on icon 22 activated
window 22. The original configuration was restored with grouping enabled.

All 15 CTest entries passed. Document and launcher cases check both directions,
stopping away from an end, cancellation, clamping, no overflow, retargeting under
a stationary pointer and insertion using the scrolled position.

## Desktop highlight on preview hover (2026-11-19)

Two overlapping green and red test windows shared a task group on the live
CachyOS Plasma Wayland desktop. With red active and in front, hovering the
green preview revealed green in the overlapping area. Moving onto the red card
showed red and faded green. Leaving the previews restored the original view.
KWin reported red as the active window throughout. The dock remained running
after closing the test windows.

All 15 CTest entries passed. The preview-model test uses an isolated D-Bus
session to verify target switching, repeated requests, stale cleanup from
another dock and cleanup on destruction. The settings tests cover independent
persistence and loading the checkbox after Apply.

## Task menus on Plasma 6.8.3 Wayland

Compared the dock with the panel task manager using an application with two windows and two audio streams. Toggling Mute changed both streams in PulseAudio. Disabling grouping separated the windows and survived restarting the dock. Enabling it regrouped them. After suspending the disposable application with SIGSTOP, More → Kill terminated it with SIGKILL and removed both windows. The native menu backend test also exercises two distinct processes and stale menu targets.

For Kill All, group two disposable processes from the same application and
keep an unrelated application open. More should offer individual targets under
Kill and a separate Kill All. Verify both test processes exit and the unrelated
application remains open. With multiple windows sharing one process, verify
that only Kill All appears.

## Capsule style on KDE Wayland

A temporary bottom dock used zero edge spacing, asymmetric positive upper radii,
negative lower radii, a two-color gradient with different endpoint opacities and
a three-pixel exterior border. The lower tips reached the screen edge and the
border followed the exposed outline. A second run used the left edge, an
eight-pixel gap and System Blur with the highlight palette role. The exposed
border and both outward curves were visible. Geometry and persistence tests
cover signed corners, a saved legacy radius and an existing custom border.

Four simultaneous test docks used a yellow desktop-side stop and a blue
screen-edge stop at a 72% midpoint. Wayland screenshots showed the blue along
the physical edge in all four orientations. The same docks were switched to
Liquid Glass with system blur to check the reflected highlight on each edge.

## Visibility and alignment on KWin Wayland

A maximized Qt test window on the VM measured 1920 × 1022 before reservation,
1920 × 953 with the bottom dock always visible, and 1920 × 1022 after switching
to Windows go below. The 69-pixel reservation included the eight-pixel gap.
At 2× magnification the outside end stayed fixed at both bottom corners. A
vertical dock aligned at the bottom hid without overlap and was recalled by
pushing the pointer against the left edge. Tests used a temporary profile.
Applying top alignment and Always visible directly in Settings moved the left
dock to the upper end. A newly maximized test window measured 1851 × 1022,
confirming the same 69-pixel reservation on the horizontal axis.

A left-edge dock aligned at the top with a 64 px margin began at y=64,
below the existing Plasma panel, and kept that end fixed when hovering its
first icon at 2× zoom. A bottom-right dock was also checked with a 96 px margin.

## Hover glow controls

Compared fixed radii of 116 and 24 logical pixels over Firefox on the live KDE
Wayland desktop with a temporary dark solid capsule. At 150% intensity and
65% opacity, the wider orange glow extended beyond the icon while the smaller
one stayed close to the pointer. QML tests exercise Apply/reopen, delivery of the
three settings to the glow and unloading it at zero intensity or opacity.

## Keyboard navigation on KWin Wayland

From a maximized probe window, Meta+Alt+Space revealed an auto-hidden bottom
dock and outlined Dolphin. Right moved the outline to Firefox, End selected the
last task, and Escape dismissed the dock. The QML fixture covers traversal,
wrapping, Home/End, Escape and Enter without launching user applications.
Repeating the shortcut selected a second, vertical dock; Down moved its
outline to Firefox. KWin reported the probe window active again after Escape.

On KWin Wayland, Menu opened the selected Firefox launcher menu. Escape
returned to that icon, Right moved to Konsole, and Shift+F10 opened its menu.

Four disposable windows formed a group on a horizontal dock under KWin. Enter
opened its previews. End scrolled the fourth card into view, and Enter activated
its window. Escape returned to the group; after reopening, Right and Enter
activated the second window, verified via KWin’s active window.

With the pointer away from the dock, the group picker stayed visible during an
idle pause. Right followed by Enter then activated the second probe window.
The QML regression test waits beyond Plasma’s deferred tooltip dismissal before
selecting the second card.

## Appearance and indicator settings cleanup

Checked the settings window on KWin Wayland with a demo profile. The settings
tree omitted the reveal animation switch and thickness alignment selector, and
retained the inactive, active, hover and group thickness controls. The settings
test also feeds both retired keys through profile normalization.

## Icon colors on KWin Wayland

Compared the same Dolphin, Firefox, Konsole and VS Code icons on three
simultaneous docks: original colors, grayscale and a custom red tint at 100%.
Shadows and highlights remained distinct. Switched the tinted profile to
the system highlight at 50% and verified the softer blue tint. The settings
test exercises Apply and reopen with a custom tint and intermediate saturation.

## Configuration sidebar

Inspected the 1060 px settings window on KWin Wayland in French. Opened
Appearance, checked the physical order of the four corner controls, added a
second demo dock, opened its removal confirmation and switched back to Dock 1
with the toolbar selector. Both entries showed the connector and monitor name.
The settings fixture exercises navigation and applying drafts across pages.

On KWin Wayland, enabling linked corners and incrementing the bottom-right
radius changed all four fields from 10 to 11. The settings fixture also checks
negative edits from every corner, Apply/reopen and independent edits after
unlinking. Inspected the paired zoom/lift fields and both pairs of dimensions
in the custom dash indicator layout.

## Minimize animation target

With Magic Lamp slowed on KWin Wayland and the Plasma task manager removed,
minimized a pink test window with the pointer at (740, 423). At 280 and 550 ms
the animation tip was within the horizontal span of its bottom dock icon near
x=1090, reaching y=1011. A second window of the same application targeted the
same grouped icon when minimized from a different pointer position.

## Uniform gradient backgrounds

On KWin Wayland, compared Solid with equal fixed gradient endpoints (#337fa5,
55% opacity, midpoint 31%, system blur enabled) in the same desktop position.
All 4590 sampled background pixels matched. Changing only the screen-side color
to #cc4422 produced a visible blue-to-red gradient. The old build also matched
for this temporary profile; the maintainer's original band was not reproduced.
The QML test compares complete rendered capsules at 0%, 40% and 100% opacity
and three midpoints, independently of the saved Solid opacity.

## Applications and sorting

On KWin Wayland with an isolated profile, dragged Firefox behind Dolphin with
the row handle, selected alphabetical sorting and saw Dolphin, Firefox and
Konsole in that order both in settings and on the dock. Switching back to
manual restored Konsole, Dolphin, Firefox. Checked the other three automatic
modes and removed an app from the Activity view. The saved manual order of
the remaining pins survived. At a 630 px window width the French Indicators
introduction wrapped to three lines inside the content area. At the default
width the screen label and selector occupied the same row.

Verified on KDE Wayland that the French window grouping and mouse actions
subheadings are centered above full-width section rules in the Behavior form.

## Debian 13.7 Plasma Wayland

On amd64 with Plasma and KWin 6.3.6 and Qt 6.8.2, the installer resolved missing
APT packages, built the shared sources, passed all 15 CTest entries and installed
the dock and desktop launcher under the desktop user's prefix. A second install
exercised the update path. The settings smoke test selects the KDE desktop
controls style to cover the removal dialog sizing on Qt 6.8.

On the active Virtio Wayland output, captures from the installed executable showed
the Dolphin launcher, a running task and the French configuration window with the
virtual monitor name. A protocol trace confirmed bindings to layer shell v5,
screen edge manager v1 and Plasma window management v17. Plasma Shell owned the
Unity and JobViewServer bus names during the test. Badge and progress delivery
still need interactive verification alongside previews, edge recall and minimize
animations. KWin reported its blur effect unloaded with this virtual GPU; check
blur and GPU-dependent rendering after switching the VM to the iGPU.

The maintainer confirmed blur on both Virtio and the Intel iGPU. On Debian
Virtio, stationary-pointer desktop captures reproduced a stale capsule outline
when the icon size changed from 52 to 28 to 64 px. Deriving its length from
the slot metrics before Row polish restored both rounded ends in all three
captures. Opening and closing an unpinned window was also checked. The initial
intermittent failure on close did not reproduce in the baseline run.
French menu tests check Close, Close All and More against the installed KDE
catalogs on both distributions.

### Drop shadows on Debian 13.7

Live Qt 6.8.2 Wayland captures on Virtio compared the default, capsule-only,
icon-only and combined shadows. Distinct fixed colors and opposite signed
offsets made each silhouette visible. Captures of the combined effects on all
four edges included grayscale icons, a negative capsule corner and an enlarged
middle icon. The settings test applies and reopens independent color roles,
strength, size and signed offsets.

## Kubuntu 26.04.1 LTS Plasma Wayland

On amd64 with Plasma and KWin 6.6.6 and Qt 6.10.2, the installer resolved
dependencies, built the dock and passed all 15 CTest entries. A staged install
included the French catalog and the desktop entry with its absolute executable
path and privileged Wayland interfaces.

In the French Wayland session, the installed dock showed Dolphin and Konsole.
A separate KDialog window appeared as a third task. The captures taken before
opening it and after closing it were identical. The settings window rendered in
French and identified the virtual output. The dock bound layer shell v5, screen
edge manager v1 and Plasma window management v20. With blur enabled, the dock
sent and committed a blur region for its surface. KWin still reported blur
loaded after a guest restart, and the installed desktop entry launched the dock.

## Kubuntu 26.10

The maintainer installed the dock and confirmed that it works on the Kubuntu
26.10 desktop. The Ubuntu 26.10 container also passed the build and test suite.

## Fedora KDE 45 Plasma Wayland

Tested on Fedora 45 x86_64 with Plasma and KWin 6.8.1, Qt 6.11.2 and Mesa
llvmpipe on a Virtio display. The shared installer resolved the RPM packages,
built the dock and passed all 15 CTest entries. The staged install included the
French catalog and a desktop entry pointing to the user-local executable.

Captures from the installed executable showed the Dolphin and Konsole launchers
on all four edges, and the French settings dialog identified the virtual output.
KWin exposed layer shell v5, screen-edge manager v1 and Plasma window
management v21 to the dock. With system blur enabled, it received a nonempty
region via the background effect surface protocol. In a temporary profile the
live task model pinned a running KCalc window, retained its launcher and icon
after closing the process, and activated it to open another KCalc window. The
saved launcher was `applications:org.kde.kcalc.desktop`.

The maintainer also completed the Fedora desktop checks with Intel iGPU
passthrough and confirmed the dock worked on that configuration.

## openSUSE Leap 16.1 Plasma Wayland

Tested on x86_64 with Plasma and KWin 6.6.4, Qt 6.11.0 and a Virtio display
using Mesa llvmpipe. The shared installer installed the dependencies with
Zypper, built the dock and passed all 15 CTest entries.

The installed dock displayed Dolphin and Konsole on all four edges. Its French
settings dialog identified the virtual output. KWin exposed layer shell v5,
screen-edge manager v1 and Plasma window management v20. With system blur
enabled, the dock sent a nonempty region through the KWin blur protocol.

In a temporary profile the live task model pinned KCalc, retained its icon
after closing its window and reopened KCalc from the saved launcher. The
installed desktop entry also launched the dock in the user's KDE session.

## Hover animation timing on CachyOS

On the Astra-Playground Wayland desktop, a probe alternated the first icon's
hover target in a live dock using a copy of the user's profile. It opened
settings, applied two icon-size changes and closed the window. At the default
90 ms duration, the transition started at settings dismissal took the following
wall-clock times (one observation per mode, including event-loop work).

| Visibility | Before | After |
| --- | ---: | ---: |
| Always visible | 195 ms | 113 ms |
| Auto-hide | 241 ms | 101 ms |
| Dodge windows | 202 ms | 108 ms |
| Windows go below | 371 ms | 110 ms |

The subsequent three transitions took 96–106 ms across the four modes after
the change. The settings test also applies the fastest slider value and checks
the saved duration when the dialog reopens.

For continuous tracking, a separate Wayland probe swept a synthetic mouse
across 17 demo icons every 900 ms, reversing at each end, with 2.2× zoom,
icon and dock shadows at 50%, glow enabled and a 90 ms hover duration. Two
9-second runs per binary sampled swap intervals on the render thread. The
95th percentile in the middle eight seconds was 18 ms on c629461 and 10 ms
with continuous tracking and stable artwork textures. At samples within 0.15
of an icon center in logical index space, the median animated fraction of its
available zoom rose from 0.20–0.24 to 0.71. These are measurements on the
CachyOS test desktop with the same scripted input, not presentation timestamps
from the maintainer's recording.

## Installer dependency reporting

A shell fixture simulated missing and installed packages for Debian 13,
Kubuntu 26.04 and 26.10, Fedora 45, Leap 16.1, Arch and CachyOS. With missing
packages, the installer listed only those packages and exited before invoking
CMake or installing packages. On rerun with the packages present, it reached
configuration, compilation, CTest and installation. The Kubuntu 26.10 package
names were also checked in the Ubuntu stonking amd64 main and universe indexes.

Family selection was also exercised with simulated os-release files and package
databases for EndeavourOS, KDE neon, LMDE, Nobara and openSUSE Tumbleweed.
A mixed missing-package result suggested the confirmed package alone and
listed the unconfirmed name separately. Supplying all dependencies on a
second run allowed the build to start. These fixtures test installer logic;
they do not qualify desktop behavior on those derivatives.

On the neon test desktop, hover-and-render completed in 40.59 s and the next
test, native-application-status, did not finish before manual interruption.
On CachyOS the original private bus activated desktop portal services during
this offscreen test. Its dedicated bus configuration now omits service
activation directories. The audio model and launcher count/progress cases
still pass. CTest limits this test to 60 seconds. To diagnose a timeout, run
`ctest --test-dir build -V -R '^native-application-status$'`.

## Capsule geometry consolidation

On CachyOS, all 15 CTest entries passed after extracting the capsule drawing
code. The QML files parsed with qmlformat and installation into a temporary
staging directory succeeded. A separate comparison with the pre-refactor
implementation produced identical fill and outline SVG strings in 120 cases,
covering both orientations, zero and fractional border widths, empty bounds
and mixed positive and negative corners. Live desktop acceptance is pending.

## Controller, task artwork and settings consolidation

The appearance and icon pages own their controls and draft serialization.
DockController coalesces visibility updates and checks overlap against the
same filtered task model. TaskIconArtwork keeps icon source and shadow texture
dimensions stable during magnification. The public settings keys are unchanged.

On CachyOS the project rebuilt, QML parsing and a staged installation passed.
The isolated Wayland demo rendered five icons inside the capsule and opened the
settings window. This visual check used one output and temporary settings.
All 15 CTest entries passed on this revision.

## Module loader and API 1

All 17 CTest entries passed on CachyOS and Debian 13.7 (Qt 6.8.2), including
package precedence, invalid manifests, wrong API/root type, missing files,
QML errors, independent instances, action dispatch, profile persistence and
the package install/update/removal test through the executable. QML parsing
passed on CachyOS. Installation into temporary prefixes passed on both systems.

On CachyOS a normal Wayland launch read an isolated enabled profile and a
fixture recorded provider completion on disk. On Debian a single-output Wayland
demo launched from the staged installation. Demo mode does not load user modules.
There is no lateral-entry rendering or module placement editor in this change.

## Unpinned applications module

All 17 CTest entries passed on CachyOS and Debian 13.7 (Qt 6.8.2). The native
task fixture runs the installed module format against a shared source model.
It checks all four sort orders, source/visual row mapping, pin/unpin, removal
and disabling the module. Settings tests cover legacy profiles, a deliberate
disable after migration, and changing the module sort without changing pin order.
Debian staged installation and package discovery also passed.

On the CachyOS Wayland desktop the installed dock displayed an unpinned KCalc
after the pinned icons. Its native Close menu action closed KCalc and removed
that slot. The settings fixture checks opening and reopening the independent module window,
including retention of an independent preference after a sort change.
The task fixture checks which rows offer module configuration. This run used a single output.

With an isolated always-visible CachyOS profile, right-clicking KCalc opened the
module window directly. Selecting Virtual desktop saved the order in that profile.

## Three-column module editor

The QML editor fixture drags blocks into an empty column, inserts before a
block, reorders within a column and moves a block back to Disabled. Native
fixtures cover two independently restored profiles, activation after moving a
generic entry, internal order in a multi-entry block, native row mapping and
the separator rules with populated sides, no pins and no providers.

On the CachyOS KWin desktop, an isolated dock profile had Dolphin pinned and
the example counter initially disabled. Dragging the counter to Left / Top
displayed the counter, Dolphin and the running tasks, with two separators.
The gear on the unpinned block opened its independent settings window. This
desktop check used one output. On Debian 13.7 the mouse-drag fixture also ran
in a mapped Qt Quick window on Plasma Wayland, using QtTest input.

## Free capsule layout

The adaptive layout fixture exercises a thin bar with floating icons, a thick
bar with overlapping icons, and a negative offset on each edge. It checks the
painted thickness, signed edge-to-edge displacement, input hit and constant exclusive
zone during magnification. The settings fixture switches modes, applies a
signed offset and checks that only Free exposes the two controls.

A temporary CachyOS KWin profile showed floating task icons over a 6 px top
bar at +52 px. The appearance page showed both controls alongside the existing
background controls. This desktop observation used one output.

The gap-crossing regression test moves the pointer from an enlarged icon into
the space before its neighbour, beyond the capsule, then out of the dock. It
failed on all four edges in both Centered and Free before the fix and passed
afterward. On CachyOS Wayland a 4 px top capsule, +68 px offset and 32 px
spacing verified sustained zoom between Dolphin and Firefox and reset on exit.

The indicator fixture in the adaptive-layout suite measures all three styles
against the screen-facing edge on four orientations with a 4 px free capsule.
It varies icon offset, saved centered padding and custom edge distance.
The settings fixture checks padding visibility. A temporary CachyOS Wayland
profile showed the indicators at a 13 px inset with a 5 px capsule and +64 px
icon offset; only the along-dock padding was visible in Appearance.

The Free layout fixture changes capsule thickness at fixed positive and zero
offsets on all four edges, and checks negative offsets up to the screen edge.

On CachyOS Wayland, increasing a top capsule from 4 to 84 px at a fixed
+50 px offset left the resting icons at the same screen position.

Free-layout dodge checks the last pixel inside each end of the resting dock
and the first one outside, horizontally and vertically on an offset output.
The four-edge layout fixture checks the resting length and reserved depth and
verifies that magnification leaves this footprint stable.
On CachyOS Wayland KCalc stayed at y=86: a horizontal move from x=42 to
x=540 and then x=1250 produced visible, hidden and visible dock states.

### Folders module

The provider fixture checks manual and alphabetical order, a context-menu
reset to the original icon, live changes to `.directory`, and safe shortcut
removal. The settings fixture opens the installed-format editor, adds and
deduplicates folders, rejects a regular file and checks moving and icon edits.
On CachyOS Wayland, the native context menu opened the French editor and its
KDE icon picker. Changing a shortcut icon updated the dock. Clicking the
shortcut opened Dolphin, and dragging a test document from Dolphin onto a
second folder copied it while preserving the source file.

In the Wayland check, dragging a directory from Dolphin onto a pinned application
added a folder shortcut. Dragging that shortcut across another dock folder in
manual order changed their positions without creating a directory on disk.
Dragging the original directory from Dolphin onto the same destination copied
its contents; the source and copied file matched. Automated cases cover disabled
and empty providers, mixed file/directory selections, alphabetical order and
persistence of the new manual order.

Folder title tooltips use the shared popup without a native task selection.
The preview tests clear a previously selected task and switch popup owners;
only loss of a previously valid task should send the dismissal signal. On
CachyOS Wayland the name stayed visible under a stationary pointer. On Debian
Wayland, moving from System Settings to Pictures to Downloads and back showed
each title while the same dock process remained alive.

### Trash module

The isolated KIO test trashes a uniquely named hidden file, checks the full
icon and enabled empty action, restores that file through KIO and verifies
both its contents and the original icon. It runs on a private bus with temporary
XDG directories on the home filesystem. It never empties the aggregate trash.
QML drop tests cover local files, folders, desktop files, copy-only offers and
remote links.

On CachyOS Wayland, a Dolphin drag moved a disposable document into the test
Trash, and clicking the module opened that location in Dolphin. In an isolated
home and private session bus, the native empty action opened KDE’s confirmation.
Cancel kept the contents and full icon. Confirming removed the test contents
and restored the empty icon.

The drop regression also toggles Trash availability during a drag. Native drag
events can enter over an unavailable slot, reject a move there and then accept
one over the adjoining application. On CachyOS Wayland, a test provider held
in its busy state showed Dolphin's forbidden cursor over Trash and the accepted
cursor over the application in the same gesture.

### USB storage module

The `usb-module` test runs against a private session bus and Solid fake
hardware. Two USB volumes appear and an internal volume is filtered out.
It exercises mount/unmount, absence of an unsupported removal action,
hot-unplug, rejection of a stale action, the empty module and reattachment.

On the CachyOS Wayland desktop, a kernel-emulated USB mass-storage gadget
backed by a disposable ext4 image exercised the system UDisks2 service.
Clicking its dock icon mounted the volume and opened it in Dolphin. With
a process holding the mount busy, unmount reported the process name and kept
the volume available. After releasing it, unmount succeeded. Reattaching
the image as a USB disk and selecting **Safely remove drive** removed the
entry from both the dock and Dolphin. The full suite passed on CachyOS and
Debian 13. A physical USB device was not part of this run.

### Standalone applications menu

The ApplicationsMenu Quick Test uses an isolated XDG menu with Internet and
Browsers groups and a fixture application. It verifies initial favorites,
independent presentations, navigation into the subgroup and returning one
level. On the CachyOS Wayland desktop the menu opened inward from a right-edge
dock, switched categories, displayed a favorite action, dismissed with Escape
and resized from the free left edge; the new width appeared in Settings.
On Debian 13 a simulated touch opened the French menu at the right-edge icon
with favorites, real KDE categories and the session controls. Session-ending
actions and simultaneous mixed-scale screens remain manual test cases.

The menu Quick Tests also cover favorite order in grid and list views, category
order, per-dock pin/unpin actions and both footer breakpoints in both resize
directions. All 19 CTest targets passed on CachyOS and Debian 13.
On the CachyOS Wayland desktop, dragging between favorites changed their order
in both views while the menu stayed open. Dropping Konsole from favorites and
Ark from the application list onto a disposable dock pinned each application.
Pinning and unpinning via the context menu updated that dock. Clicking the KDE
profile opened Users in System Settings. A fresh menu showed seven direct
buttons in French. Dragging the free edge inward grouped Session first and
then Power; both buttons opened their corresponding actions. No session-ending
operation was invoked.

An additional regression test starts a favorite drag and unloads the source
popup before releasing the pointer. This reproduces the lifetime sequence
from the maintainer's Qt abort. On CachyOS Wayland, dropping Ark from a Plasma
Search result and Konsole from Favorites added the missing launcher and left
the dock running. A copy of the maintainer's bottom-dock profile retained
its shadow and zoom settings during testing.

With a saved menu size of 818 × 633 logical pixels, KWin received and granted
856 × 671 including transparent margins, both at the bottom-left corner and
near the bottom of the right edge. The geometry test checks the native slide flags
for all four edges and the fallback for limited cross-axis space.

On CachyOS Wayland, the bottom-left menu met the resting dock at zero screen-edge
spacing and showed a matching 16 px gap with shadows and zoom enabled. KWin kept
the same 856 × 671 surface size in both cases. On the right edge, a 128 px gap
was visible on both sides of the dock with shadows and zoom disabled. The Quick
Test checks 0, 16 and 128 px on all four edges with a thin capsule and protruding
resting icons, including the input and dodge bounds.

The search test uses a disposable krunnerrc and service catalog. It finds the
fixture application when its provider is enabled, returns to Favorites when
cleared, then checks an empty result set with the provider disabled. The live
settings button opened the Plasma Search KCM.

With a 28 px shadow on CachyOS Wayland, the pointer moved laterally across
several dock icons inside the menu's shadow and their zoom followed it.
Clicking the launcher through the shadow closed the menu. The menu body is
still a native popup above the dock when the painted surfaces overlap.

On Debian 13.7 with Qt 6.8.2, a virtual USB mouse reproduced the original
lost grab on the first move. Dragging the corrected right edge by 120 px
changed the menu from 960 to 1080 px wide. A top-right corner drag then
produced a 1008 × 550 menu. Closing and reopening it yielded the same
1056 × 598 native surface including its shadow. The core tests cover the
input outline, the shadow on resize and a button release outside the popup.

### Menu and manual reorder animations

On CachyOS Wayland, a bottom-edge module popup requested KWin's slide effect
from the bottom. Dragging Konsole from first to last reordered the dock and
persisted the launcher list. Dragging Dolphin onto Konsole in the favorites
grid exchanged their positions. In Applications and sorting, dragging the first
row by its handle to the third row saved the order shown on release. These
checks used a disposable dock profile. The dock gesture test also checks that
crossing a slot updates the destination before changing the task model.

### External insertion previews

On CachyOS Wayland, dragging Kate from Dolphin into a disposable dock opened
a space between Firefox and Konsole before release and saved Kate between them.
Holding a directory over Firefox for two seconds opened a space in Folders.
Moving across the folder icons shifted the space and dropping there saved the
shortcut between the two indicated neighbours. A quick drop on a folder icon
copied the directory into the destination on disk.

The QML tests exercise the launcher gap on all four edges, the two-second
folder dwell across moving targets, insertion at the end, exit/re-entry and
direct copy routing. The module test checks ordered insertion, deduplication,
stale destinations and automatic sorting.

### Applications menu scrolling and subcategories

On CachyOS Wayland a disposable menu contained Internet → Navigateurs.
Opening the subcategory showed Firefox and the current category beside the
Back button. Returning restored the parent category. The menu tests check
the header, forward/back navigation and wheel distances at the default 4×
and at both ends of the 1×–10× range, including consecutive notches,
reversals and pixel deltas.

On CachyOS with Qt 6.12, one discrete Wayland wheel tick reported both an
angle delta of −120 and a pixel delta of −15, a touchpad device type and no
scroll phase. At 10×, the old menu jumped straight to 150 px. The corrected
menu reached the same position over approximately 100 ms with intermediate
positions. A regression test sends both that event and a phased touchpad update.

### Dock context menus at the pointer

On CachyOS Wayland, a right-click at (101, 34) on Firefox in a top dock placed
the native menu corner at (101, 34), with the launcher closed and with it open.
On Debian 13 (Qt 6.8), a long dock was tested with the launcher at its left
end, at both the top and bottom of the output. A right-click beyond the
visible launcher's right edge opened the native menu at the clicked icon
while the launcher remained visible. QML tests
exercise off-center mouse anchors on all four edges. Native tests cover late
window parenting with multiple docks and output-boundary constraints.

### Capsule application icon

In a staged installation, the application entry and the autostart template both
reference `org.sarbalabs.PlasmaNextDock`. The matching SVG in
`share/icons/hicolor/scalable/apps` matches the source file. Running the
uninstaller against that prefix removes the installed icon.
