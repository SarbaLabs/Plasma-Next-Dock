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
