# Development history

These entries retain the plans, acceptance notes and open questions recorded at
the time of each change. For current priorities, see the [roadmap](roadmap.md).

## Next steps after PR #26

1. **Fix the gradient background.** With identical colors and opacities on the
   desktop and screen-edge sides, the capsule should look the same as a Solid
   background with that color and opacity. The reported defect is a visible band
   in the middle. Compare both modes over the same desktop with the same blur
   setting, including partial opacity and different gradient midpoints.
2. **Refine the configuration window.**
   - Fix the introductory text in Indicators so it wraps inside the available
     width and stays clear of the vertical scrollbar. Check the French text.
   - Use Appearance as the layout reference across sections. At normal window
     widths, place the main labels on the left and their related controls on
     the right. Keep narrow layouts readable.
   - Rename Pinned applications to **Applications and sorting** (*Applications
     et tri* in French). Move the sort order control here from Behavior, put
     **Add an application** at the top, and show pinned apps by icon and name.
     Support drag-and-drop reordering in manual sort mode. Review the
     maintainer’s forthcoming layout and interaction details before implementing
     this page.
3. **Investigate Debian 13 as the minimum supported platform.** Target KDE
   Plasma 6.3.6 and Qt 6.8.2 if feasible. Build, install and exercise the dock
   on that Wayland stack, checking runtime features and private API dependencies.
   Debian 13.7 now passes compilation, installation, CTest and a live KWin
   startup with the settings window. The maintainer confirmed blur on Virtio and the Intel iGPU. Remaining
   desktop interaction checks are tracked separately; see [Debian results](testing.md#debian-137-plasma-wayland).
4. **Clean up and reorganize the code.** Remove obsolete, unused and redundant
   code. Group functions and components by responsibility and clarify the file
   structure and dependencies between modules. Add concise comments above
   important blocks to explain their purpose and technical choices. Simplify
   where that improves readability. Preserve existing features and saved
   configurations, using automated tests and the established desktop regression
   scenarios to verify each change.

## 2026-11-13 — Standalone foundation

The maintainer created SarbaLabs/Plasma-Next-Dock and authorized initial development,
reuse of suitable Plasma macOS Dock components, and project documentation.
The working branch is `feature/standalone-prototype`; target branch is `main`.

Implemented: independent layer-shell host, separate geometries, real KDE task model,
initial task activation, demo mode, four edges, screen selection, continuous zoom,
bounded optional glow, corner radius, window-avoidance controller and native edge
adapter. User-local build/install/uninstall scripts and regression tests accompany it.

**Foundation accepted and PR #1 merged by the maintainer.** See docs/testing.md for the
actual scope of automated evidence. This is a prototype to validate architecture,
not feature parity with Plasma macOS Dock and not a replacement recommendation.

## Extended desktop matrix (still pending)

- Check actual layer placement, input passthrough, overlap and edge recall on CachyOS.
- Check task activation and launchers with the actual KDE model and installed apps.
- Test all edges, multiple output origins, fractional scale, fullscreen policy,
  interaction with existing panels and reveal/leave sequences.
- Preserve the accepted capsule-only dodge and edge corridor while expanding the dock.

## Subsequent stages, not implemented yet

1. Optional autostart (explicit opt-in), application chooser and further configuration polish.
2. Extend native context menus as future grouping/audio-stream features are added.
3. Keyboard navigation improvements, external drops and badges; grouped previews are now under validation.
4. Port the optional blur component with its full lifecycle regression coverage,
   then System Blur/Liquid Glass and the established indicator/bounce features.
5. Multiple dock instances, output reassignment and packaging.

Preserve the existing working dock throughout this process. Do not bulk-copy its
Plasmoid-bound root or claim parity merely because some visual files are shared.
No release or automatic merge is planned for this foundation PR.

## Edge spacing requirement — 2026-11-13

The maintainer requires a pixel-based capsule-to-screen-edge spacing setting in
the final settings UI (both smaller and larger than the prototype's 8 px gap).
The input corridor must follow the actual capsule geometry at every spacing;
window collision must remain capsule-only. The current fix deliberately derives
the corridor from geometry instead of hardcoding 8 px.

## 2026-11-13 — Settings and launchers

Branch: `feature/settings-and-launchers`, based on merged `main`. Implemented:
normal keyboard-capable configuration window, persistent geometry/appearance/dodge
settings, native KDE Pin/Unpin, saved launcher order, immediate reorder/remove
controls, desktop-entry-ID addition, and Configure/Quit menu actions. The spacing
requirement above is now exposed (0–128 logical px).

The host scopes layer-shell to the dock alone. Screen/edge changes rebuild that
surface; other settings update the live scene. Demo/smoke sessions never read or
write normal settings. No autostart or migration from the old plasmoid is added.
Desktop validation of these new interactions is pending; the foundation's accepted
behavior is preserved as a regression requirement.

### Interaction follow-up

PR #2 now includes direct icon drag reordering, immediate settings-list order
updates, and edge-aware context menu anchoring. Local nine-test suite passes;
Wayland popup placement and native running-task drag behavior await desktop checks.

### Settings-stage desktop follow-up

- Maintainer validated immediate ordering and drag reordering.
- Replace QML-only menu placement with explicit native Wayland anchor/gravity;
  retain four-edge fallback geometry. Automated checks pass; KWin confirmation pending.
- Generate the desktop entry with an absolute Exec path so host portal registration
  does not depend on ~/.local/bin being in the portal's PATH. GLib loading verified;
  maintainer portal confirmation pending.

## 2026-11-14 — Adaptive sizing

The maintainer confirmed both final PR #2 corrections (native popup placement and
portal registration) on CachyOS and merged PR #2. Settings, pinning, immediate
ordering and in-dock drag are the accepted baseline.

Branch `feature/adaptive-dock-sizing` adds count/output-based icon and capsule
reduction, preservation of preferred settings, a normal 24 px floor and wheel/
trackpad overflow. Local validation is recorded in testing.md. Real desktop
validation remains pending; native application menus are the next planned stage.

Sizing follow-up: desktop testing found premature shrink caused by reserving full
zoom for every task. The branch now budgets only local magnification and caps
animation tails independently of the resting size. Regression coverage includes a
crowded list that still fits at its preferred size. Awaiting desktop confirmation.

Maintainer validated adaptive shrink/recovery. Wheel scrolling remains under
validation: synthesized and horizontal events now have explicit coverage and
fixed-root handlers; all nine local tests pass. No further sizing change.

## 2026-11-14 — Adaptive sizing accepted; native context menus

The maintainer confirmed adaptive shrinking, size recovery and wheel scrolling.
PR #3 was merged into main at `075e62607d81ae37c64ce3f17be5bf65076bf258`.

Branch `feature/native-context-menus` adds native PlasmaExtras menus, desktop
application actions, Places, recent documents with KDE privacy/activity filtering,
window operations, desktops/activities and MPRIS playback controls. It retains
Pin/Unpin, Configure and Quit. A persistent model index prevents a popup from
acting on a replacement task. No global shortcut backend is instantiated.

Standard menu labels use KDE's translation domain and original contexts; a project
catalog includes French for dock-specific commands. Appearance follows the native
widget style, with no custom opacity or background. See docs/context-menus.md.
Wayland positioning, theme matching, live recent documents and actual window/media
operations remain maintainer desktop acceptance items. Do not merge automatically.

## Final-version parity requirement

The maintainer requires at least the capabilities developed in plasma-macos-dock:
macOS/Plasma/Custom indicator modes, native group symbol and independent task
frames; segment/state dimensions, color sources and separate unfocused color;
opacity/minimized handling, animations and edge-aware placement. Also retain
bounce, complete native menus, bounded configurable hover glow, pixel corner
radius and the established System Blur/Liquid Glass lifecycle fixes. The removed
nonfunctional custom overflow + is not a parity requirement. Track these explicitly
rather than treating the current simple running dot/count as the final renderer.

## 2026-11-14 — Grouped windows and native tooltips

PR #4 was merged at `a39bc3f7b6734bd95733c106e7d224c8acf5b6ee` after maintainer
acceptance and successful CI. Native menus, their localization and positioning are
now part of the accepted baseline.

Branch `feature/grouped-window-previews` introduces native TasksModel grouping,
a separate ungrouped collision model, persistent-index window selection and
interactive Plasma tooltips. Explicit edge location replaces the generic attached
Controls.ToolTip which had no knowledge of the dock edge. Capture uses KDE
ScreencastingRequest/KPipeWire, with an icon fallback and bounded visible cards.
The application desktop entry declares the screencast interface for older KWin.

The small group count is an interim affordance. It does not replace the full
indicator parity requirement above. No blur, bounce or styling settings are
silently removed or declared implemented. See window-previews.md for architecture
and the pending CachyOS acceptance matrix. Do not merge automatically.

### PR #5 desktop positioning correction

Maintainer video showed tooltips offset from their icons, notably on top/right
edges. Native Plasma placement used Qt's normalized layer-window origin. A
per-dock LayerSurfacePosition adapter now keeps Qt's client geometry consistent
with the known layer-shell placement. Native tooltip appearance is unchanged.
All 12 local tests pass; actual desktop placement requires follow-up validation.

## 2026-11-14 — Advanced indicators and native reveal animation

The maintainer accepted the corrected native preview placement and merged PR #5
at e74bb141c02074e27e9e7e28b4f609b37f886162. Preserve that per-window coordinate fix.
Branch feature/advanced-indicators ports macOS/Plasma/Custom indicator controls,
independent native group/decorations, bounded child state and the dedicated settings
tab. Settings now use the project's KI18n catalog, with French translations.

The requested soft edge reveal uses KWin's native Sliding Popups effect, enabled
per dock with a persistent toggle. Unlike the initial discussion's proposed local
speed slider, duration follows KWin: the Wayland protocol has no per-window duration.
No system setting is changed or second animation layered on top. See indicators.md.

This stage does not implement blur, Liquid Glass, bounce, badges or every final
parity feature. Those remain on the roadmap. Desktop validation of this branch is
pending; do not merge or release automatically.

The maintainer reports the indicator/reveal stage works, with cross-axis indicator
drift during magnification on bottom/right docks. A focused resting-lane correction
and frame-sampled regression tests address this feedback; desktop confirmation of
the correction remains pending. Settings cleanup is explicitly deferred until the
final development stage; do not remove controls in this iteration.

## Capsule background stage — 2026-11-14

The maintainer accepted the bottom/right magnification correction and merged PR #6.
Branch feature/capsule-backgrounds starts from main at
27e79e277315bbc210dd271c597b4a1baa336284 (tree e466186d4ad4603a0b4b1a421e29426732ce455c).

Add Solid/Transparent/Translucent/System Blur/Liquid Glass modes with native
single-window effects ownership, shared rounded geometry and theme-based paint.
Reuse the existing radius setting; do not duplicate or migrate it. Solid remains
the default. Settings cleanup, bounce, badges and other parity items remain deferred.
The headless validation does not replace CachyOS/KWin desktop acceptance.

### PR #7 desktop refinements — 2026-11-15

Background rendering is accepted by the maintainer. Remove the three ineffective
blur tuning controls, add theme/custom border color and thickness (zero disables),
and expose independent icon spacing plus long-axis/short-axis padding. Preserve
the existing radius and screen-edge gap controls. Validate adaptive fit and all
four orientations. This is focused feedback; general settings cleanup stays deferred.

### Hover controls — 2026-11-15

Add blast radius and hover lift to PR #7. Preserve the existing falloff at radius 2
and default lift to zero; both settings persist. Reserve the variable zoom budget
and lift headroom in adaptive layout, keep resting indicators fixed, and validate
all four inward directions. Also check fixture file opening instead of ignoring
QFile::open's nodiscard result on newer Qt.

## Application status — next stage

The maintainer accepted PR #7 backgrounds, spacing and hover controls and merged
it into main at `5113bd89a6b2d1a50aa39f1b10ede11fd0a1c911`.
Branch `feature/application-status` adds native audio matching/mute, MPRIS preview
controls, application volume, native SmartLauncher counters/progress and a preview
toggle. See application-status.md for test scope and pending desktop acceptance.

Confirmed order after this branch: **behavior settings plus the pinned/unpinned
separator**, then bounce. Do not silently advance these into the current scope.
The older chronological entries describe historical milestones, not current gaps.

## 2026-11-15 — Application status accepted; behavior and separator

The maintainer confirmed audio/media/status fixes and merged PR #8. Base main is
8dc6126ed4d87180ca3094c8871f0726dd151c34 (tree 93d61ffebaf9549ba8db6b7b68cb0aa2233e62ee).
Branch `feature/behavior-and-separator` adds the agreed behavior settings and native
pinned/unpinned boundary. See behavior.md for defaults, architecture and acceptance.
No bounce, autostart, release or broad settings cleanup is included. Bounce remains
the next agreed stage. Desktop acceptance of this branch is pending.

## 2026-11-15 — Behavior accepted; icon bounce

The maintainer confirmed the final wheel correction and merged PR #9. Base main:
6ef8c889f50d8bcb95dcc575675b6aa66b2f5ea8 (tree 3df1146a42c345ec4153b7f92aafc28127218819).
Branch feature/icon-bounce adds configurable launch/attention feedback and the
native Test Bounce Animation action. Preserve behavior filters, separator, immediate
wheel cycling, status integrations, indicator anchors, blur and capsule-only dodge.
See bounce.md for defaults and pending desktop acceptance. General settings cleanup,
packaging and optional autostart remain outside this stage; no automatic merge.

## 2026-11-16 — Bounce interaction refinement

The maintainer confirmed bounce playback but reported lost edge clicks and zoom
flicker during launches/animation. PR #10 now uses stable per-task edge input
lanes, coalesces transient model counts before sizing and retains launch feedback
by service identity through delegate replacement. CachyOS acceptance of these
corrections remains pending; do not merge automatically.

The edge click lane was accepted. Follow-up feedback isolates residual shrinkage
to cursor crossing the moving icon edge and initial launcher replacement. Window
pointer observation and initialization without a zoom transition address those
cases; live CachyOS validation is still pending.

The maintainer accepted stationary-pointer bounce tracking; only the first-window
size dip remained. Follow-up model-transition tests exposed a numeric row anchor
surviving a launcher move/replacement. Retain service identity and the fractional
hover position through that transition. This last correction awaits desktop testing.

The maintainer confirmed bounce, click lanes and first-window zoom now work.
A final diagnostic cleanup addresses TaskStatus work queued beyond delegate context
lifetime; the distinct KDE service-registration warnings are documented without
hiding them or taking service ownership away from Plasma.

### Icon-bounce branch: hover polish

- Added default-on native icon hover highlight with an Indicators toggle.
- Expanded task decorations inward while preserving the outward indicator anchor.
- Selected the active palette explicitly for the non-focusable dock's indicators.
- Added persistence, hover toggle, four-edge frame envelope and palette coverage.
- User-theme appearance and CachyOS Wayland rendering remain manual acceptance.

### Follow-up from desktop hover/color feedback

- Reproduced icon/frame hover loss when crossing into the tooltip area; a four-edge
  pointer regression fails before and passes after replacing child hover delivery
  with the existing window-level logical task anchor.
- Custom renderer and preview now share the explicit active Qt SystemPalette
  highlight, rather than separate Kirigami attached palette bindings.
- Previous frame envelope sizing is retained; desktop color confirmation pending.

## 2026-11-16 — PR #10 accepted; external drag and application chooser

The maintainer confirmed the final highlight/palette correction and merged PR #10.
Branch feature/external-drag-and-drop starts from main b35d1c00f823f6cfc0245976480cba1634b3b48f.
Add a searchable installed application chooser, external launcher pinning, document
URL dispatch to native tasks and delayed activation while dragging. The maintainer
accepted all four features after several days of use on 2026-11-19. See
external-drops.md for scope and continuation.
Optional autostart, multiple docks/screens and general settings cleanup remain later.

## 2026-11-19 — External drops accepted; PR #11 ready

Maintainer reports no detected problems after several days of desktop testing.
Implementation CI run 43819877812 succeeded. Final preparation is documentation-only;
no additional installation or desktop retest is required for that update. PR #11
is prepared for manual merge, not recorded as merged until the maintainer does so.
The next proposed stage remains optional autostart, followed by multiple docks and
output management; neither is implemented by this branch.

## First-launch clipping (2026-11-19)

The initial canvas now includes the tasks available at component completion.
The four-launcher left-edge layout was verified on KWin. See [startup measurements](testing.md#initial-launcher-layout-on-kwin-2026-11-19).

## Optional login startup (2026-11-19)

The settings checkbox enables per-user KDE session startup. The install script
preserves the user's choice on updates. See [validation and the remaining login
check](testing.md#optional-login-startup-2026-11-19). Multiple independent docks
and output assignment are the next planned feature after desktop acceptance.

## Multiple docks and outputs (2026-11-19)

The dock selector, independent settings and launcher lists, and output-aware
hosts are implemented. Two edges on one physical output were verified on the
VM. The maintainer validated physical multi-monitor operation on CachyOS,
including mixed scale factors. See the [test matrix](testing.md#multiple-docks-and-outputs-2026-11-19).

## Choosing a grouped window during document drag (2026-11-19)

A document drag can raise a specific group member through its preview and
continue into the chosen window. This was exercised end to end with Dolphin on
KWin Wayland. Drag scrolling along the overflowing dock remains a separate task.

## External drag scrolling (2026-11-19)

Documents and installed application launchers can scroll an overflowing dock
from either end. The real Wayland document drag was validated using 48
ungrouped windows on a vertical dock; see [testing](testing.md#external-drag-scrolling-on-an-overflowing-dock-2026-11-19).

## Desktop highlight on preview hover (2026-11-19)

Hovering a window card uses the KWin Highlight Window effect to reveal the
corresponding window on the desktop. A per-dock setting controls the feature.
Focus preservation and restoration were verified on the live Wayland desktop.

## Task menu comparison

The task menu now includes native frame and capture controls, per-dock application grouping exceptions, audio mute and both process-specific Kill and group-wide Kill All actions.

## Capsule colors and corners

Per-dock palette roles, fixed tints, two-stop gradients, exterior borders and
four signed corner radii support floating and edge-attached styles.

Solid, Liquid Glass and Gradient now share an independent system-blur option.
Gradient balance and glass reflections follow the configured screen edge.

## Visibility and alignment

Four visibility policies and physical start, center and end alignment are selectable for each dock.

Each dock can offset its aligned end along the screen edge with a saved margin.

## Hover glow

Each dock now exposes glow radius, intensity and opacity. The reference fork at
cd5fa9d9 uses a fixed 70 px default; Next Dock retains automatic radius for
existing profiles and offers the same 1–256 px manual range.

## Keyboard navigation, first stage

The global focus shortcut, visual-order traversal, activation and Escape are
implemented. Menu and Shift+F10 open the selected task’s context menu.
Enter on a group opens its previews for keyboard selection, including off-screen cards.
The picker stays open while waiting for the next key.

## Appearance and indicator settings cleanup

Dock hide and reveal always use the native slide hint. Custom indicator segments
share a center line, with independently configurable state thicknesses.

## Icon colors

Each dock can display original, grayscale or tinted grayscale task icons.
The tint uses a fixed color or a system palette role, with adjustable saturation.

## Configuration layout

Six sidebar sections separate placement, appearance, icons and animations,
indicators, behavior, and pinned applications. The header selects docks by
number and screen and provides add/remove actions. Corner radii follow their
physical positions; padding and edge offsets keep their per-dock semantics.

Corner radii can be linked per dock, using the top-left radius when linking.
Magnification and hover lift share a row. Custom indicator dimensions are grouped
by active and inactive state.

Window tasks now publish icon geometry for KWin minimize animations. Grouped
windows share the group icon. Geometry changes are coalesced as the dock moves
icons and scrolls.

## Uniform gradient rendering

Matching resolved endpoint colors and opacities now use the Solid fill path.
A fully transparent gradient suppresses hover glow like a fully transparent
Solid background. Desktop comparison and regression coverage are in docs/testing.md.

## Applications and sorting

The settings sidebar now includes Applications and sorting. Sort changes and pin
edits take effect immediately for the selected dock. Manual sorting provides a
drag handle and move buttons. Automatic sorting follows the native task model
and preserves the stored manual order. The desktop settings forms use side-by-side
labels and fields and collapse on narrow windows. The Indicators introduction
wraps above its form with space reserved for the scrollbar.

## Dock and icon drop shadows

Appearance and Icons and animations each have a per-dock drop shadow with a
palette or fixed color, strength, size and screen-relative X/Y offsets.
Debian 13 installs the Qt Quick Effects runtime through the shared installer.
See the [Debian visual checks](testing.md#drop-shadows-on-debian-137).

## Kubuntu 26.04 LTS

The shared installer now resolves the Kubuntu 26.04 and Debian 13 package sets.
Kubuntu 26.04.1 passed compilation, installation and live Plasma Wayland checks.
See the [tested versions and results](testing.md#kubuntu-26041-lts-plasma-wayland).

## Fedora KDE 45

The shared installer detects Fedora 45 and reports missing RPM packages with a DNF installation command.
The dock passed build, install and live KWin checks on Plasma 6.8.1 and Qt
6.11.2. See the [Fedora desktop checks](testing.md#fedora-kde-45-plasma-wayland).
The maintainer also validated Fedora with Intel iGPU passthrough.

## openSUSE Leap 16.1

The shared installer reports missing dependencies with a Zypper installation command. The installed dock
passed the automated suite and live Wayland checks on Plasma 6.6.4 and Qt
6.11.0. See the [Leap desktop checks](testing.md#opensuse-leap-161-plasma-wayland).

## Hover animation timing

Magnification defaults to 90 ms and can be adjusted per dock from 10 to
140 ms in Icons and Animations. The dock uses elapsed-time Qt Quick animations
and preserves its drawing options when settings visibility alone changes.
See the [four-mode timing measurements](testing.md#hover-animation-timing-on-cachyos).
During continuous movement, icons follow the latest pointer target on the next
animation frame. Their artwork and shadow textures keep a stable size during
magnification.

## Installer dependency checks

Before compiling, the installer reports missing packages and the manual
installation command based on the distribution family and local repository metadata. Kubuntu 26.10
shares the Kubuntu 26.04 package list. The maintainer validated the dock on the Kubuntu 26.10 desktop.

## PRs #35–37 — Hover tracking, dependency reporting and Bazzite

PR #35 stabilized hover tracking during continuous pointer movement and added
per-dock animation speed. PR #36 added package-family detection and missing
dependency reporting, including the KDE neon package and test fixes. PR #37
documented the maintainer-tested Bazzite KDE build in a Fedora 45 Distrobox.

## Modular v1.0 delivery record

The following design and acceptance notes retain the original delivery sequence, including the native launcher study. The standalone Applications menu was the implementation shipped in the source tree.

### Interfaces to preserve

- `DockHost` owns each LayerShellQt surface, output, anchors and exclusive zone.
  `ScreenEdge`, `LayerSurfacePosition`, `BackgroundEffects` and `PopupAnchor`
  isolate compositor-specific operations. Keep the standalone process independent
  of Plasma Shell and keep existing private integrations behind their adapters.
- `LiveTasks.qml` and the KDE task models supply identities, grouping, launcher
  membership and actions. Keep the separate ungrouped collision model available
  to `DockController` regardless of which modules are enabled.
- The core owns pinned launchers, appearance, indicators, layout, hit testing,
  magnification, bounce, visibility, adaptive sizing and scrolling. Keep existing
  native menus, persistent action targets, previews and minimization geometry.
  `DockProfiles` and `DockSettings` remain the owners of per-dock persistence.
- Modules supply entries, state changes, entry actions and optional settings.
  The core places and draws all entries. Expose only the task services or events
  a module needs, keeping internal Qt objects and animation state private.

### Delivery sequence and acceptance

Each row is independently reviewable. Adjust sequencing only for technical
dependencies. Record automated results separately from real KWin observations.

| PR | Deliverable | Acceptance |
| --- | --- | --- |
| 1 | Module discovery, validation, loader, common API and developer guide | Install, update and remove an example without rebuilding the core. Reject incompatible packages and keep valid ones working. |
| 2 | Migrate existing unpinned applications into an official module | Pin/unpin or close a running group without duplicate or missing tasks. Disabling the module preserves window avoidance. |
| 3 | Three dock zones and drag-and-drop settings editor | Move and reorder blocks across two independent profiles, restart and verify order, separators on populated sides only and empty zones without gaps. |
| 4 | Custom bar geometry | Verify both modes on all four edges, including hit regions, effects and stable space reservation during animation. |
| 5 | Folders module | Add, open, reorder and remove shortcuts. Removing a shortcut preserves the directory. |
| 6 | Trash module | Open, drop, empty and verify automatic theme icon updates, cancellation and error handling. |
| 7 | USB storage module | Hotplug multiple devices and exercise supported actions, including a busy-device failure and last-device removal. |
| 8, optional | Study native KDE launchers, then integrate only if feasible | Record feasibility evidence for the standalone host. A documented decision to omit this module is acceptable. |
| Final, if needed | Consolidation across modules | Verify migration, stability, animation performance and supported desktops before packaging. |

### Module contract and installation (PR 1)

The initial loader, API 1 provider and inspection commands are implemented on
the module-manager branch. See the [developer guide](modules.md) and
[installable counter example](../examples/modules/org.example.counter).
PR 2 supplies the first official provider, unpinned applications, with its own
settings window for per-dock sorting, accessed by right-clicking a task supplied by the module.
PR 3 implements the three-column Modules editor, per-profile block placement and
automatic separators. The following stage adds per-dock capsule geometry in Appearance.

Discover packages under `plasma-next-dock/modules/` in the XDG user and system
data directories. Distribution packages can install a shared copy under
`/usr/share`; users can install their own under `$XDG_DATA_HOME` (normally
`~/.local/share`). Define deterministic precedence for duplicate IDs and test
user override/removal. At startup, validate manifests and instantiate enabled,
compatible implementations. Replacing a compatible module and restarting the
dock must suffice for an update. Simple Qt 6/QML modules should require no C++
build. API 1 uses metadata.json, Main.qml and an optional Settings.qml.

Require a stable module ID, localized name and description, module version and
supported API version. Expose availability, zero or more entries with stable IDs,
icons and presentation state, primary action, context actions and change
notifications. Support nested actions and enabled states. The core builds native
menus and always offers **Configure Plasma Next Dock** and **Quit Plasma Next Dock**
on pinned apps, module entries and empty space. Modules may expose settings in
the dock configuration and optionally in their menus. Scope functional settings
to their owner and store placement independently per dock. Document any shared
settings explicitly.

Skip invalid manifests, incompatible APIs and detectable QML load errors with a
diagnostic identifying the module and cause. Disabled modules need no functional
instantiation. Missing and empty modules occupy zero space. Official and third-party
modules use the same infrastructure. Third-party modules run as user code in the
dock process and can crash it. Document removal of a faulty module and restart
as the recovery procedure. Process isolation is outside the v1.0 scope.

Deliver `docs/modules.md` alongside the implemented contract, covering metadata,
entries and icons, click handling, contextual actions, settings, installation,
removal, updates and API compatibility. Keep official modules small and commented
so they serve as working examples.

### Task migration and layout (PRs 2–3)

Reuse the existing window and launcher identities through a controlled interface
to the KDE task model. Migrate unpinned task presentation, actions, previews
and status into the module. The core keeps pinned applications and the underlying
task services. Preserve launching, activation, grouping, window actions, menus,
thumbnails, indicators, badges, audio, MPRIS, drops, keyboard navigation, sorting,
scrolling, desktop/activity filters, zoom, bounce and dodge. Test transitions
between pinned and unpinned while windows are open. Migrate saved profiles to an
matching supported automatic sort. Use the right/bottom side until the editor ships.

The settings editor has **Left / Top**, **Disabled** and **Right / Bottom** columns.
Pinned applications stay in the center outside the editor. Drag whole modules
within or between columns. The top of either active list is the outermost block.
Render the trailing side in reverse block order, preserving the module's internal
entry order. For example, leading blocks Menu then USB and trailing blocks Trash
then Folders render as **Menu · USB · Pins · Folders · Trash**. In PR 3, draw one automatic separator between the pinned block and each side
that has visible module entries. On a vertical dock the same rule applies above
and below the pins. Closing the last unpinned application removes its separator
and spacing if no other module is visible on that side. With no pins, omit the
pin boundaries. Empty or disabled modules occupy no space. Persist each dock's layout
independently and support the same module on multiple docks where appropriate.

### Bar geometry (PR 4)

Centered mode is the default for existing profiles. Free mode has two
independent per-dock settings: background thickness and icon offset relative
to that background. Use them for both overlapping icons on a thick capsule and
floating icons above a thin bar. Resolve offsets relative to the selected edge.
Compute background, icon placement and input regions separately. Preserve fills,
gradient, system blur, Liquid Glass, corners, borders, shadows and indicators.
Use resting sizes for reservation so zoom and bounce never move desktop windows.

### Official modules (PRs 5–8)

- **Folders** provides per-dock local shortcuts, manual and alphabetical order,
  drag-in addition and icon overrides in its module settings. A primary click
  opens the folder and dropping documents copies them with KIO. See
  [module details](modules.md#folder-shortcuts-and-provider-actions).
- **Trash** opens `trash:/` and uses KIO for asynchronous drops and emptying,
  respecting KDE confirmations and errors. Its KIO directory lister tracks content changes for
  `user-trash` and `user-trash-full`.
- **USB storage** uses Solid events for insertion, state changes and removal. Each partition shows its mount state in the indicator area.
  Each visible volume offers open, mount, unmount and hardware-supported safe
  removal. See the [USB module checks](testing.md#usb-storage-module).
- **KDE launcher, optional** investigates real Kickoff (default), Kicker and
  Application Dashboard. Seek native open, edit applications, configure launcher
  and show alternatives actions. Omit the feature if it requires fragile shell
  modifications, extensive KDE code duplication or unstable dependencies.

The separately designed **Applications menu** uses KDE's application hierarchy
and per-dock favorites with a dock-styled popup. Favorites can be reordered,
applications pinned from the menu, and session actions grouped to fit the available width.
The gap between the popup and the resting dock follows that dock's screen-edge spacing.
The shadow passes pointer input through to the dock. Free edges and corners support mouse resizing on both Qt baselines.
The menu also searches installed Plasma Search providers through KF6 KRunner. It does not host launcher
plasmoids. See the [menu verification](testing.md#standalone-applications-menu).

Manual reorder previews and the compositor-driven menu transition landed in PR #50. External launcher and folder insertion previews landed in PR #51. Running applications can also be dragged to the pinned section. Dropping a pinned application or folder shortcut on the Trash module removes its shortcut. The same target unmounts mounted USB volumes or requests safe drive removal from an unmounted volume, with a red cross when the operation is unavailable. PR #52 added adjustable smooth wheel scrolling and directional subcategory transitions. PR #53 placed dock context menus at the pointer, including over the applications menu. The project now uses the Capsule SVG as its application icon.
Appearance includes an optional extended dock with symmetric end margins and independent content alignment. An extended dock can keep modules at both ends and independently align and scroll the pinned applications between them. Start and end alignment show the separator next to the aligned pins when modules occupy that end. Window avoidance is clipped to the owning output. The visibility choices are Always visible, Auto hide and Dodge windows. Older overlay profiles now reserve space in Always visible mode.

The applications menu supports directional keyboard navigation and the Plasma launcher shortcut on outputs without a native launcher.

Dock and applications-menu shadows follow the exterior capsule outline independently of background opacity.
Shadow texture margins use the effective inverted corner radius on thin capsules.

### Validation before packaging

Run build, CTest, QML checks, isolated install and migration tests per PR. Cover
discovery, invalid or missing modules, disabled/empty entries, version changes,
activation, layout persistence, block reordering, empty sides and task regressions.
On Plasma Wayland verify four edges, concurrent docks, mixed scaling and output
hotplug, menu and preview targeting, grouped windows, drops, graphics effects,
hide/recall, zoom and bounce. Exercise independent module replacement and removal
and verify pinned applications throughout. Compare hover smoothness against the
accepted dock; avoid per-frame allocations, polling and repeated layout work
from an empty module. Record the tested Qt/Plasma versions.
