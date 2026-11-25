# Development status and roadmap

The original desktop scope and source-install compatibility campaign are validated.
Version 1.0 also requires independently installable modules. Packaging follows
module development and cross-feature acceptance. Each PR targets manual review
and merge. Functional work requires the maintainer's authorization after this
roadmap has been approved and merged.

| Phase | Status | Milestone |
| --- | --- | --- |
| 1. Original desktop features | Accepted | Preserve the desktop behavior recorded below |
| 2. Source compatibility | Validated | Keep a common source tree through the Debian baseline |
| 3. Code consolidation | Accepted and merged | [Cleanup PR #39](https://github.com/SarbaLabs/Plasma-Next-Dock/pull/39) |
| 4. Modular v1.0 | Planned | Deliver the reviewed sequence below |
| 5. Packaging | Planned | Validate artifacts and independently updatable modules |
| 6. First release | Planned | Publish documentation, compatibility and verified artifacts |

## 1. Functional development

The accepted scope includes independent docks and output assignment, visibility
and edge reservation, launchers and sorting, grouped previews, drag and drop,
keyboard navigation, appearance and optional login startup. Keep the desktop
regression scenarios for all four edges, existing panels, fullscreen windows,
edge recall, and continuous hover while moving across icons. On CachyOS the
maintainer exercised independent Samsung and AOC outputs at different scales,
including disconnection and reconnection.
[Desktop acceptance records](testing.md#multiple-docks-and-outputs-2026-11-19)

## 2. Distribution compatibility

**Manual desktop validation.** CachyOS is the development and reference
desktop. The maintainer also validated Debian 13.7, Kubuntu 26.04.1 LTS and
26.10, Fedora KDE 45 and openSUSE Leap 16.1. Debian establishes the oldest
tested combination of Plasma/KWin 6.3.6 and Qt 6.8.2.
[Debian baseline](testing.md#debian-137-plasma-wayland)

Eight additional desktops passed the maintainer's source-install campaign:

| Package family | Validated desktops |
| --- | --- |
| Debian / Ubuntu | MX Linux KDE, KDE neon |
| Arch | EndeavourOS, Manjaro KDE, Garuda Linux |
| Fedora | Nobara Linux KDE, Bazzite KDE |
| openSUSE | openSUSE Tumbleweed KDE |

On Bazzite KDE the maintainer compiled inside a Fedora 45 Distrobox and
confirmed the dock worked after returning to the host desktop.
[Bazzite installation procedure](../README.md#bazzite-kde-build-with-distrobox)

**Automated validation.** The regression suite has 17 CTest entries. GitHub
Actions checks dependency reporting, compilation, tests and staged installation
in Debian 13, Ubuntu 26.04 and 26.10, Fedora 45 and Leap 16.1 containers.
Monitor hotplug, mixed scaling, pointer feel and compositor effects are covered
by desktop testing. [CI workflow](../.github/workflows/build.yml) ·
[Test records](testing.md)

## 3. Code cleanup and consolidation

Work on a dedicated branch, preserving features, user settings and the
`./install.sh` workflow. Remove obsolete or duplicated code, group components
by responsibility, clarify module dependencies and add concise comments where
a technical choice is otherwise hard to recover.

Acceptance of PR #39 covered all 15 CTest entries and a staged installation
on both CachyOS and Debian 13.7. On Debian, a single-output Wayland demo rendered
the dock and settings. On CachyOS, the maintainer tested two differently scaled
displays, all four edges and per-dock appearance and icon changes. Disconnecting
an output hid its dock and preserved the profile with the output marked
disconnected. All five CI builds passed.

Retain the indicator parity checklist during consolidation:

- macOS, Plasma and Custom modes, native group symbols and independent task frames.
- Per-state segment dimensions, edge placement, color sources and separate unfocused colors.
- Opacity, minimized-window handling and indicator animations.

## 4. Modular v1.0

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
- **USB storage** uses Solid events for insertion, state changes and removal.
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

Manual reorder previews and the compositor-driven menu transition landed in PR #50. External launcher and folder insertion previews landed in PR #51. Menu navigation polish adds adjustable smooth wheel scrolling and directional transitions between nested categories.

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

## 5. Packaging

Prepare native packages for Arch, Fedora, Debian, Ubuntu and openSUSE from the
shared sources. Test installation, launch, upgrade and removal for each target.
The dock uses private Qt GUI headers, so verify each binary against the Qt
build shipped on its target.

For Bazzite, prototype a lightweight AppImage using the host KDE libraries.
Validate library compatibility and Wayland integration on Bazzite before
publishing it. The tested Distrobox procedure remains available. Evaluate
other immutable distributions individually.

Package official modules into XDG system data directories. Test independent upgrades,
user-installed modules and compatibility with the shipped Qt/Plasma versions.

## 6. First release

Finish the user guide and installation, upgrade and uninstallation instructions
for source builds and published packages. Publish a compatibility matrix with
tested versions, installation method and the scope of manual and automated
checks. Prepare the first GitHub release with its tag, release notes and
verified artifacts.

The [development history](development-history.md) retains the original PR
notes, earlier plans and the [indicator parity checklist](development-history.md#final-version-parity-requirement).
