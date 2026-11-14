# Grouped windows and interactive previews

## Scope and native mechanisms

This stage follows the accepted native context menus. LiveTasks has two native
TasksModels: grouped presentation (GroupApplications, no inline grouping, no count
threshold), and ungrouped collision with identical desktop/activity filtering.
Grouping must never hide an individual window from the avoidance calculation.
Existing pinning, launcher order and in-dock movement continue through KDE APIs.

WindowPreviewModel exposes the selected root's window children, or its single
window. QPersistentModelIndex protects activation and closing from a changing row
order. Source changes are coalesced on the GUI thread; invalid targets dismiss the
preview. A destroyed source or stale index cannot route a command to a replacement.
Closing a grouped context menu target uses KDE's Close All; preview close buttons
operate on one child. Ambiguous multi-window media actions are suppressed as in KDE.

## Position, ownership and appearance

The previous Controls.ToolTip had no panel edge information. PlasmaCore.ToolTipArea
now receives the actual edge explicitly: bottom opens above, top below, left right,
and right left. Plasma owns placement, screen-boundary constraints, theme margins
and tooltip background. The visual parent is the corresponding icon, including
its magnified position. No custom opacity or theme background is painted.

Each icon sets the shared TaskPreview's name, icon and target before showing it.
The native tooltip sets its owner reference. Temporary reparenting while switching
owners must not clear the newly selected model; hidden-model cleanup is deferred
and rechecks visibility. Showing an interactive preview inhibits dodge. Starting
a drag or context menu dismisses it. Single-window activation remains the existing
click action; clicking a group shows its window selector.

## Capture and cost

WindowThumbnail uses TaskManager.ScreencastingRequest with the window UUID, and
PipeWireSourceItem to display the node. KPipeWire is a runtime dependency. Capture
objects exist only for on-screen, non-minimized cards while the popup is visible.
There is no polling timer, background capture service or icon readback loop.
Titles and icons remain usable when a stream is absent, a window is minimized or
capture is unavailable. This is not a cached screenshot of a minimized window.

The popup has a bounded ListView (up to three cards in its initial viewport),
with scrolling for larger groups. Horizontal docks use a horizontal list;
vertical docks use a vertical list. Delegates outside the viewport do not capture.

The application's own desktop file declares `zkde_screencast_unstable_v1`, in
addition to its existing task protocols. Older KWin checks requested interfaces
against desktop metadata and the executable path; the installer already writes a
quoted absolute Exec path. No global permission setting is changed. Current KWin
also restricts privileged interfaces for sandboxed clients; this project is a
normal user-installed native executable, not a sandbox bypass.

## References and licensing

- KDE libplasma `src/declarativeimports/core/tooltiparea.cpp`: shared mainItem,
  location-to-popup-direction mapping, visual parent and interactive keep-alive.
- KDE plasma-desktop task manager: grouped TasksModel and ScreencastingRequest.
- KDE KWin `src/wayland_server.cpp` (Plasma/6.3 and current master): interface access.
- Our plasma-macos-dock PipeWireThumbnail.qml: LGPL-2.0-or-later wrapper attribution
  is retained in WindowThumbnail.qml and docs/licensing.md.

## CachyOS acceptance — pending

Use ./install.sh after updating this branch; quit and restart only Plasma Next
Dock. Ensure kpipewire is installed. Keep the stable dock installed separately.

1. Open two or more Dolphin/Konsole/Firefox windows. One icon should represent
   each application; its count follows windows opening/closing.
2. Hover and click the group: verify titles, live thumbnails, activation of each
   child, individual close, and correct active highlighting. Minimize one window:
   its icon/title remains usable and activation restores it.
3. Move between applications without leaving the dock. Names, thumbnails and
   targets must follow the current application. Hover an idle pinned launcher too.
4. Check bottom, top, left and right edges: popup adjacent to the correct icon,
   toward the screen interior, including first/last icons and a scrolled dock.
5. Move into the preview and its buttons: it remains open and the dock remains
   visible. Leave both: dismissal restores ordinary dodge/edge recall.
6. Close/open/reorder windows while the preview is open. No stale action may affect
   another application. Large groups scroll and release off-screen captures.
7. Check Pin/Unpin, persisted order, drag reorder, native menus including Close All,
   adaptive shrinking, wheel scrolling, magnification and bounded glow.
8. Check dodge with each member of a group separately, current desktop/activity
   filtering, multiple outputs, fractional scale and theme changes.

Headless tests validate model routing, native component imports, tooltip ownership
and explicit edge configuration. They do not validate live PipeWire images, KWin
popup placement, GPU performance, real input crossing between surfaces or actual
application close/activation. Those remain maintainer desktop acceptance items.

## Desktop positioning follow-up

The maintainer's recording exposed a coordinate-origin defect despite correct
edge selection: a top-dock tooltip was shifted left, and right-dock tooltips could
appear at the opposite screen edge. The native tooltip is not an xdg menu popup;
its Plasma placement helper derives global anchors from the parent QWindow position.

Qt Wayland's QWaylandWindow::setGeometry normalizes ordinary top-level positions
to the output origin. The dock's original QWindow::setPosition call therefore did
not publish the actual layer-shell origin. The compositor independently centers
and edge-anchors the dock. Plasma then added the wrong origin to the icon's local
rectangle. Explicit tooltip location alone could not repair that discrepancy.

LayerSurfacePosition now publishes DockGeometry::surface's known origin into the
client-side QPlatformWindow geometry and delivers a synchronous Qt geometry
notification. It intentionally bypasses QWaylandWindow::setGeometry's normalization,
without sending a Wayland move, changing the surface size, setting a global Qt
flag or replacing the native tooltip. All coordinates remain logical pixels.

The adapter is attached only to the dock's layer-shell window. It coalesces
move/resize/show/native-surface lifecycle events, restoring bookkeeping if a later
configure resets it. Reentrancy protection and an equality check prevent a feedback
loop. Output and adaptive-size changes use the host's existing origin calculation.
The settings window and native context-menu positioner are unchanged.

This is a small Qt GUI-private compatibility adapter (the project already requires
matching GUI-private headers). Revalidate after Qt upgrades. Reference:
Qt qtwayland v6.8.2 src/client/qwaylandwindow.cpp and current qtbase
src/plugins/platforms/wayland/qwaylandwindow.cpp; libplasma
src/plasmaquick/popupplasmawindow.cpp and transientplacementhint.cpp.

A dedicated test simulates the normalized backend geometry and checks correction,
mapToGlobal, unchanged sizes, all four edges, nonzero/negative output origins and
surface destruction/recreation. Actual KWin placement still needs the maintainer's
follow-up using the same four-edge desktop scenario.
