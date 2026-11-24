# Standalone host architecture

## Decision

Plasma Next Dock owns a Qt Quick surface with the layer-shell role. It does not
borrow a transparent Plasma panel or elevate the desktop containment. The host
uses LayerShellQt and the existing compositor interfaces; no KWin script or binary
effect is required by this first prototype.

Three geometries have different responsibilities:

1. **Canvas:** accommodates the maximum magnified icon height and task strip.
2. **Input region:** rounded capsule plus a continuous hover band across the visible task strip extending to the physical edge,
   intersected with canvas bounds. Transparent margins do not receive pointer input
   under Qt Wayland's QWindow mask implementation.
3. **Dodge region:** Centered layout tests the rounded capsule in output coordinates.
   Free layout tests the aligned resting span of the dock, using the same
   depth supplied to the exclusive-zone surface. Hover keeps the dock visible.

The canvas is fixed during hover for a given task count; only the task row changes
size. Long lists scroll within the output-limited canvas. Negative output origins
are handled explicitly; all geometry is in logical coordinates, not physical pixels.

## Components

- `src/main.cpp`: validated CLI, screen selection, single live-instance lock,
  LayerShellQt setup and resource-backed QML. The surface uses LayerTop, no keyboard
  focus, and exclusive zone -1: anchored to the output. Always-visible mode adds a transparent, input-free layer surface with a positive exclusive zone on the same output. Its single edge anchor keeps the reservation independent of corner alignment and hover animations.
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
`plasma-next-dock` / `org.sarbalabs.PlasmaNextDock`. Optional login startup uses a user-owned XDG autostart symlink targeting the
installed KDE desktop entry template. The settings window reads the link state
each time it opens. Login and manual launches share the live instance lock.
DockProfiles owns a DockSettings object per saved dock. Dock 1 uses the existing
flat INI keys, additional docks use numbered groups in the same file, and the
collection stores their order. One application lock and one login entry cover
the whole collection. Each visible dock has its own host, QML engine, task models,
controller and native screen-edge object. Explicit assignments use the Qt output
name. Disconnecting a monitor retires its surfaces and retains the assignments.
If all assignments are unavailable, the first dock temporarily appears on the
primary screen so the configuration window stays reachable.

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

### Native popup positioner follow-up

Desktop testing confirmed that explicit QML popup coordinates alone did not fix
placement on the maintainer's Qt version. Recent Qt Quick sets
`parentControlGeometry` from the Menu's parent Item, and Qt Wayland uses that
rectangle instead of the requested window coordinates. A root-parented menu is
therefore anchored at the root's bottom-left, independently of the click.

`PopupAnchor` now supplies an explicit parent-local one-pixel anchor and inward
xdg positioner gravity via Qt's `_q_waylandPopup*` compatibility properties.
It applies before the popup role is created (SurfaceCreated), updates a reused
popup before opening, and only targets Popup windows transient to the prepared
dock window. QPointers handle window destruction; other settings-window popups
are untouched. Anchors are clamped inside the host surface; KWin can slide the
menu to fit the output. This does not resize the dock or change input/collision
regions. The QML position remains a fallback for non-Wayland previews.

The adapter uses no new dependency or private header, but the property names are
an internal Qt compatibility contract and must be checked after Qt upgrades.
Sources consulted (APIs used, no source copied):
- [Qt Quick popup parent control geometry](https://github.com/qt/qtdeclarative/blob/dev/src/quicktemplates/qquickpopupwindow.cpp)
- [Qt Wayland positioner overrides](https://github.com/qt/qtbase/blob/dev/src/plugins/platforms/wayland/plugins/shellintegration/xdg-shell/qwaylandxdgshell.cpp)
- [Qt 6.8 positioner compatibility](https://github.com/qt/qtwayland/blob/6.8/src/plugins/shellintegration/xdg-shell/qwaylandxdgshell.cpp)

### Desktop identity and host portal

Qt registers `org.sarbalabs.PlasmaNextDock` with the host portal. The matching
.desktop file existed, but its `Exec=plasma-next-dock` required the portal process
PATH to contain the install directory. GLib desktop-entry loading checks the
executable and can reject the whole entry if it cannot resolve it. Installation
now generates a quoted absolute Exec path, honoring install-time --prefix and
DESTDIR without embedding the staging root. This needs no portal restart,
PATH modification or global desktop configuration change. A nonstandard prefix
outside XDG application search directories still requires normal XDG discovery.
Source: [GLib desktop app info loading](https://github.com/GNOME/glib/blob/main/gio/gdesktopappinfo.c).

## Adaptive task sizing

`AdaptiveLayout.js` derives effective dimensions solely from task count, preferred
icon size, zoom, selected output dimensions and edge gap. The width budget is the
resting row (count * preferred size + gaps + end padding) plus at most two full
zoom equivalents for the local squared falloff. It is scaled when exceeding the
output axis minus 16 logical pixels. Hover/animated Row width never feeds back
into the base-size decision, preventing oscillation.

Each delegate reports changes of its animated zoom weight to a shared total and
subtracts its contribution on destruction. If animation tails overlap enough to
exceed two equivalents, only their zoom increments are proportionally capped.
Normal local magnification remains below that limit. This requires no scan or
polling and preserves the existing 90 ms per-icon animation. The base scale does
not depend on the aggregate; shrinking is solely count/settings/output driven.

The scale normally stops at 24 logical pixels per icon. Cross-axis fitting can
override that floor on pathological tiny outputs, and clamps an impossible edge
gap. Icon spacing, end padding and capsule thickness scale together; the saved
radius and edge gap retain their normal meanings. Preferred settings are read-only
inputs. Magnification animates its factor rather than absolute pixels, so count
or output changes immediately respect the new bounds without stale larger icons.

Overflow at the floor uses the existing Flickable content, with wheel/trackpad
input and clamped offsets on content/output changes. Left dragging belongs only
to native task reorder, avoiding competing Flickable grabs. The popup envelope
ignores offscreen icons. Input remains clipped to the drawing surface and dodge
continues to follow the capsule only. No timers or compositor changes are added.

Wheel input is received by unrotated root-level handlers rather than the
Flickable's content. Explicit Mouse|TouchPad acceptance also enables synthesized
system wheel events (Qt rejects them with the default Mouse-only filter).
Separate axis handlers feed one routing function; diagonal input is consumed once,
pixel deltas take precedence and the current event position updates hover mapping.
The handlers are enabled only for actual overflow with the context menu closed.
Source reference: Qt `src/quick/handlers/qquickwheelhandler.cpp`,
`wantsPointerEvent()` device/source and orientation checks (Qt 6.8).

## Group presentation and previews

The presentation TasksModel groups application windows. A separate GroupDisabled
model supplies individual window geometry to DockController with the same activity
and desktop filters. Launcher persistence remains on the presentation model.
WindowPreviewModel exposes only the selected task's leaves via persistent indexes;
its queued, coalesced updates avoid reading the model mid-notification.

Main.qml supplies a shared TaskPreview to PlasmaCore.ToolTipArea. Explicit
Bottom/Top/Left/Right edge location chooses the inward side; the actual icon is
its visual anchor. Native Plasma handles tooltip placement and theming rather than
PopupAnchor, which remains specific to context menus. Preview visibility inhibits
dodge until the native interactive tooltip dismisses. See window-previews.md.

### Known layer-surface origin

Qt Wayland can report the screen origin for ordinary top-level windows even when
layer-shell places them elsewhere. LayerSurfacePosition publishes the host's known
edge-centered surface origin to Qt's coordinate mapping without moving/resizing
the compositor surface. Native Plasma tooltip placement then has a valid parent
origin. Keep this per-window adapter separate from PopupAnchor (xdg menus), and
never change Qt's process-wide fixed-position flag. See window-previews.md.

## Indicator composition and compositor animation

DockIndicators uses an upright resting lane, separate from the magnified icon.
Only its longitudinal extent follows the slot; its cross-axis anchor stays fixed
to the capsule. Fractional centering is preserved on rotated vertical layouts.
It never changes layout dimensions. It composes KSvg native frames/strips and group elements with
CustomIndicators. The existing macOS dot remains in its original slot geometry.
IndicatorTaskState observes model events and reads at most eight children; icon
colors share the existing lazy ImageColors loader with the glow.

IndicatorsSettings adapts the prior plasmoid's configuration page to this host's
settings map and Apply/Close transaction. No KConfig/Plasmoid dependency is added.
The configuration engine has its own KLocalizedQmlContext using plasma-next-dock.

ScreenEdge registers a KWindowEffects slide hint for its edge and preserves native
hide/recall ownership. Registration is cached and restored after surface lifecycle
changes; KWindowEffects handles effect-manager availability. There is no client
position/opacity animation, polling or global KWin configuration mutation.

## Capsule effects ownership

The standalone host owns one BackgroundEffects instance for its QQuickWindow.
DockController emits capsuleChanged only for capsule geometry/radius changes,
separately from animated icon input regions. This supplies the same effective
radius used by CapsuleBackground, its border, gloss, glow and collision path.

BackgroundEffects coalesces GUI-thread updates, caches the rasterized region, and never observes render-thread/per-frame signals. It
restores after show/exposure, native surface creation and application palette
changes, clears requests before surface destruction, and defers application until
visible/exposed. KWindowSystem independently restores remembered requests when its
Wayland effect managers return. Native compositor hiding preserves the mapped
surface and its requests; it does not require a QWindow hide event.

There is no PanelView in this process to overwrite the dock's effects. The old
plasmoid's panel mask/floating and delayed Plasma theme hooks would solve shared
panel ownership issues that do not exist here and are intentionally not imported.
See backgrounds.md for fallback, visual limits and desktop acceptance.

### Border and independent spacing refinement

User feedback removed ineffective blur saturation/contrast/brightness controls
and native contrast registration. The old INI keys are ignored. BackgroundEffects
now owns blur alone. CapsuleBackground exposes its existing border width/color;
theme color stays the default, with an explicit custom override and zero-width off.

Separate iconSpacing, horizontalPadding (long-axis ends) and verticalPadding
(short-axis thickness) replace the shared/hardcoded 10/12/10 values. AdaptiveLayout
budgets all three before zoom and output fitting; all scale with icon shrinkage.
Short capsules use actual content plus end padding rather than a minimum 160 px.
The canvas retains magnification headroom, and input/dodge use the updated capsule.

### Configurable magnification reach and lift

blastRadius (0–8, default 2) controls the number of neighboring icon centers within
the squared falloff. The existing 2.4-icon denominator is preserved at the default
(radius + 0.4); radius zero uses a half-icon interval and affects only the nearest
icon. Fractional pointer positions retain continuous interpolation.

AdaptiveLayout computes a bounded sum of falloff weights for the selected radius.
The same budget caps overlapping animation tails and reserves canvas length before
hover, preventing clipping or a wide radius being flattened by the old fixed budget.
The default keeps the former two-icon-equivalent reserve.

hoverLift (0–64 logical px, default 0) adds an inward offset using the same animated
weight, independent of zoom amplitude. It works even at 100% magnification. Extra
headroom is reserved before hovering, participates in adaptive fitting, and never
changes the resting capsule or dodge region. Input lanes cover the complete lift/bounce envelope to the physical edge; preview
anchors follow the actual lifted icon. Indicators remain in their separate resting lane.

## Application status adapters

TaskStatus composes installed plasma-pa, MPRIS and SmartLauncherItem APIs without
instantiating the full taskmanager Backend. Overlay and preview controls stay
independent of geometry, collision, background effects and running indicators.
Matching refreshes follow model events rather than animation frames. See
[application-status.md](application-status.md) for lifecycle, defaults and tests.

## Presentation behavior and boundary

BehaviorSettings drafts and persists only its own keys. LiveTasks applies native
KDE grouping/sorting/filtering to the presentation model, leaving the ungrouped
collision model's scope unchanged. TaskBehavior routes click/cycle requests without
creating another backend. Output geometry is global logical geometry.

Row direction reverses presentation, never saved launcher identity. A coalesced
IsLauncher/HasLauncher boundary adds one scaled separator span to AdaptiveLayout;
icons and indicators share its longitudinal offset and preserve their resting
cross-axis anchors. Overflow wheel handling takes precedence over optional group
cycling. Attention is an independent opt-in hide inhibitor. See behavior.md.

## Icon bounce composition

TaskBounce produces a normalized jump/rebound offset; Main adds it to icon hover
lift along the inward cross-axis. AdaptiveLayout reserves maximum headroom before
animation. Indicators and capsule stay in their resting geometry. Task input
lanes cover the reserved bounce envelope through to the physical edge without
following the animated y coordinate. Dodge remains capsule-only.
Native task startup/attention roles and launch requests drive animations; disabled,
dragging, hidden-policy and preview states stop them at rest. See bounce.md.

### Window-level magnification input

DockController observes the dock QQuickWindow's pointer events without consuming
them. Its target item maps window coordinates into the dock; hover is membership
in the same region used by the Wayland input mask. The band spans inter-icon gaps and uses the maximum zoom and lift while hovered, so a shrinking neighbour cannot uncover the pointer mid-crossing. Individual lanes still target clicks and drops. Main updates magnification's
logical pointer index only for changed positions or real window entry, not child
hover re-delivery during bounce. The previous root HoverHandler is removed; native
menu/tooltip/audio input routing remains intact. Target/window changes detach the
observer. New task delegates enable zoom interpolation only after initialization.

The magnification anchor retains its delegate/service identity and fractional
position, not only a numeric model row. Index changes remap it without consulting
animated geometry. A replacement delegate recovers the service anchor and snaps
its initial zoom before enabling interpolation; real pointer movement replaces the
anchor. This prevents first-window proxy transitions briefly reducing icon size.

## Installed applications and external drag

LauncherResolver is shared as an API by the settings and dock engines. It queries
KDE's installed service catalog and canonicalizes launcher identity without loading
arbitrary desktop entries. ExternalDrop owns only drag reception and a single-shot
activation timer; a separate persistent MenuTarget protects against row reuse.
Native TasksModel handles pinning and opening URLs. See external-drops.md for the
accepted URL policy, UI behavior, limitations and desktop validation checklist.

During explicit keyboard navigation the selected host temporarily requests layer-shell on-demand keyboard interactivity. Escape, activation and loss of window focus return it to no keyboard interactivity. Demo and smoke runs do not register a global shortcut.
