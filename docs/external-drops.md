# Application selection and external drops

Branch: feature/external-drag-and-drop. Base main: b35d1c00f823f6cfc0245976480cba1634b3b48f,
with PR #10's final hover/color fixes accepted by the maintainer.

## Architecture

LauncherResolver queries installed KService applications through KApplicationTrader.
The chooser queries on opening, filters locally by translated name, generic name
and desktop ID, and supports keyboard search/selection. Canonical applications:
URLs identify installed services. Local launcher files must resolve to an installed
service's canonical entry path. Arbitrary desktop files are neither imported nor
executed. No shell command is assembled. No dependency is added.

ExternalDrop is one Qt Quick DropArea over the existing dock input geometry. Its
presence does not enlarge the surface or collision region. Internal reorder keeps
its existing DragHandler. External offers are classified once on entry and checked
again at drop, bounded to 128 URLs. Mixed documents/launchers and unsupported schemes
are rejected. CopyAction means delivery of the URLs, not moving/copying the files.

Application drops use native requestAddLauncher, canonical duplicate checking and
saved launcher order. Existing launchers are not moved by duplicate drops. Manual
sort respects the insertion boundary; other native sort modes keep their semantics.
File drops use native TasksModel.requestOpenUrls and its application/KIO handling.
Acceptance confirms dispatch, not that the target supports every document type.

A separate MenuTarget instance holds a persistent model index for document targets.
The 650 ms single-shot dwell timer activates a running task, never toggles minimize.
Moving to another target restarts it; leaving/canceling stops it; destroyed targets
cannot receive actions. A group opens its native window previews. The tooltip surface
accepts supported document drag offers independently of the dock. A 350 ms
dwell over a visible card activates its persistent model target. The preview remains visible and accepts
another selection until the drag leaves the panel, ends or is cancelled.
The tooltip does not take ownership of the document drop. When a group exceeds
the preview viewport, its edge zones scroll the cards during the drag.

During an accepted document or launcher drag, the outer 28 logical pixels of an
overflowing viewport scroll its contents toward that end while space remains.
The viewport coordinate system follows the layout on all four edges. After each
scroll step, hit testing updates the document target under a stationary pointer.
Window activation and group preview dwell resume when scrolling stops. Launcher
insertion uses the visible positions at drop time.

DropArea.containsDrag inhibits dodge. Highlighting uses that target during external
drag; ordinary hover still uses the established window pointer observer. The
native input mask, bounce, popup positioning and capsule blur stay unchanged.
The component is disabled in demo mode. There is no global drag hook or polling.

## Maintainer acceptance — 2026-11-19

The maintainer tested this branch over several days on CachyOS Wayland and confirmed
all four delivered functions work as expected, without detected problems: application
selection/search, external launcher pinning, document opening and drag-hover window
activation. GitHub Actions run 43819877812 passed for implementation commit
6dcf3dabf2b44af5b3c1fee0b2137832eb8c1816. PR #11 is ready for maintainer review/merge;
no automatic merge is authorized. This final update changes documentation only.

An overflowing dock scrolls an accepted external drag in either direction. The following checklist is retained for future
regression checks; the general acceptance does not certify every source/output mix.

## Manual regression checklist

- Open the chooser; search by name/ID, use Down/Enter/Escape, pin, and repeat without
  duplicates. Confirm installed Flatpak application entries are included by KDE.
- Drag installed applications from Dolphin and the KDE application launcher; test
  insertion before/after pinned icons, all four edges and reversed layout.
- Restart and check saved order; confirm non-manual sorting retains its setting.
- Drag one/multiple documents onto a compatible launcher/running app; verify actual
  opening and that the original files are untouched. Test URL escaping/spaces.
- Hover a document over a running task, then move into its activated window to drop.
  Check minimized windows, groups, cancellation and closing the target mid-drag.
- Test Wayland drag permissions, edge recall, HiDPI, multiple screens and overflow.
  Compositor/source drag behavior cannot be proven by offscreen tests.

## Automated coverage

Isolated installed-service fixtures cover catalog search, canonical file/application
identities, duplicate prevention and insertion, invalid/mixed payload rejection.
Synthetic Qt drag enter/move/drop/leave events exercise the actual DropArea delivery.
Timer tests cover activation, invalidation and cancellation. Native TasksModel tests
cover adding/reordering saved launchers without replacing the model. Existing tests
continue covering menus, previews, audio, bounce, hover, layout, blur and persistence.
