# Standalone host architecture

## Decision

Plasma Next Dock owns a Qt Quick surface with the layer-shell role. It does not
borrow a transparent Plasma panel or elevate the desktop containment. The host
uses LayerShellQt and the existing compositor interfaces; no KWin script or binary
effect is required by this first prototype.

Three geometries have different responsibilities:

1. **Canvas:** accommodates the maximum magnified icon height and task strip.
2. **Input region:** rounded capsule plus the currently rendered icon rectangles,
   intersected with canvas bounds. Transparent margins do not receive pointer input
   under Qt Wayland's QWindow mask implementation.
3. **Dodge region:** the rounded visible capsule translated into output coordinates.
   Empty canvas margins never trigger window avoidance. Icon silhouettes are not
   part of this initial collision policy; hover keeps the dock visible.

The canvas is fixed during hover for a given task count; only the task row changes
size. Long lists scroll within the output-limited canvas. Negative output origins
are handled explicitly; all geometry is in logical coordinates, not physical pixels.

## Components

- `src/main.cpp`: validated CLI, screen selection, single live-instance lock,
  LayerShellQt setup and resource-backed QML. The surface uses LayerTop, no keyboard
  focus, and exclusive zone -1: no reserved desktop work area, anchored to the output.
- `src/geometry.*`: pure geometry functions for placement, rounded contact and input.
- `src/controller.*`: event-driven collision checks against a QAbstractItemModel.
  Changes are coalesced through a queued invocation. Only geometry changes request
  recalculation; moving a glow alone does not scan windows.
- `src/screenedge.*`: isolated Qt Wayland protocol adapter. Generated bindings come
  from the installed plasma-wayland-protocols package. Qt private native surface
  access is contained here. Destruction/Hide releases the edge object.
- `qml/LiveTasks.qml`: KDE TasksModel with grouping disabled and current desktop/
  activity filters, also used by the controller. Activation stays in KDE's model.
- `qml/DemoTasks.qml`: inert fixture; it never launches apps or changes window state.
- `qml/Main.qml`: initial task strip, solid capsule, continuous zoom, bounded glow.
- `qml/CapsuleGlow.qml` and geometry helper: reused from Plasma macOS Dock.

## Hide and reveal lifecycle

The controller requests hiding only when a relevant non-minimized window overlaps
the capsule, dodge is enabled, the edge extension exists, and neither hover nor the
short leave grace period inhibits hiding. If the extension is missing, the controller
keeps the surface visible. Repeated equal requests do not send protocol operations.

The adapter creates the edge object only after the layer surface exists/exposes.
It sends `activate` to hide through KWin; it never calls QWindow::hide for avoidance.
KWin reveals the surface on edge activation. Pointer entry then clears the request
with `deactivate`; a later leave can re-arm it if overlap remains. The protocol does
not provide a visible-state event, so `hideRequested` is policy intent, **not proof
that the compositor currently hides the surface**. Lifecycle behavior needs real
KWin tests, including reveal without immediately entering the capsule.

Native screen-edge reservation uses the surface extent, not a custom capsule
segment. This remains a documented recall-span limitation, distinct from premature
hiding, which the separate collision region addresses.

## Isolation and maintenance

Installation defaults to ~/.local and uses the unique executable/desktop ID
`plasma-next-dock` / `org.sarbalabs.PlasmaNextDock`. There is no autostart, service,
config migration, global environment setting or plasmoid plugin registration.
Output removal recreates the dock on the primary remaining screen; simultaneous
multi-instance/multi-output management is future work.

The KDE screen-edge and task-manager APIs are desktop integration interfaces,
not a promise of cross-compositor or indefinite binary compatibility. In particular,
Qt private headers require rebuilding against the installed Qt version. Missing
runtime QML modules fail visibly rather than silently producing an empty dock.

## Sources consulted

- [Plasma PanelView](https://github.com/KDE/plasma-workspace/blob/master/shell/panelview.cpp)
- [Plasma AutoHideScreenEdge](https://github.com/KDE/plasma-workspace/blob/master/shell/autohidescreenedge.cpp)
- [KDE screen-edge protocol](https://github.com/KDE/plasma-wayland-protocols/blob/master/src/protocols/kde-screen-edge-v1.xml)
- [KDE WaylandTasksModel](https://github.com/KDE/plasma-workspace/blob/master/libtaskmanager/waylandtasksmodel.cpp)
- [KWin layer-shell windows](https://github.com/KDE/kwin/blob/master/src/layershellv1window.cpp)

These inform the design; they do not replace desktop validation of this host.

### Edge input corridor

The pointer region also includes the gap between capsule and physical screen
edge, with a connector through outward rounded corners and an edge strip across
the full surface recall span. This lets edge-only recall produce hover entry and
subsequent exit, rearming dodge after the existing leave grace period. It allows
continuous magnification while moving along the physical edge. Interior drawing
margins remain click-through. This corridor is neither painted nor used for
window collision, and follows capsule geometry for future configurable spacing.

## Persistent settings and launcher stage

`DockSettings` owns a validated QVariantMap backed by QSettings in the application's
own INI file. Unknown keys are ignored, numeric ranges are clamped and non-finite
values fall back to defaults. Launcher URLs are structured desktop-entry URLs,
normalized/deduplicated without interpreting commands. Writes use QSettings sync;
errors are shown in the configuration window. Demo/smoke modes use memory only.

`DockHost` owns the view, controller and screen-edge adapter as one lifecycle unit.
The application keeps the configuration engine separate. LayerShellQt::Window::get
selects layer-shell for the dock only; the former process-wide Shell::useLayerShell
call is removed, leaving configuration windows on normal xdg-shell. The configuration
window can take keyboard focus while the dock cannot. Settings/menu interaction
inhibits hiding. Screen/edge changes queue reconstruction of the host, destroying
QML before the controller; this surface recreation is not used for ordinary dodge.

The live TasksModel uses SortManual, separateLaunchers and launchInPlace. Pin/Unpin
calls its native requestAddLauncher/requestRemoveLauncher methods and persists the
resulting launcherList. Settings reorder that list without modifying desktop files
or launching shell commands. The model still remains ungrouped for collision checks.
No KDE global shortcuts backend is instantiated.

Source reference: LayerShellQt `src/interfaces/window.cpp` (including v6.3.4) for
per-window shell selection; KDE `libtaskmanager/tasksmodel.h` for launcher APIs.
These APIs are used, not copied into this repository.

### Context menu placement and reorder gestures

Menu popup coordinates are explicitly relative to the dock root, using the click
along the dock axis and the visible capsule/icon envelope on the cross axis.
Negative margins prevent fitting a window popup inside the narrow host. Saved
launcher lists are observed directly from DockSettings; external order changes
reset the native manual sort map through SortDisabled -> SortManual. Native drag
moves keep their current manual map and sync/persist only at release.

The root DragHandler outlives moving delegates, uses the system movement threshold
and never starts applications. Dragging inhibits dodge and temporarily removes
zoom; native TasksModel enforces pinned/unpinned barriers. A task-count change ends
the current drag instead of retaining a stale row index.
