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
