# Development status and roadmap

Updated after PR #37. The functional scope and source-install compatibility
campaign are complete. **Code consolidation is in progress.**

| Phase | Status | Milestone |
| --- | --- | --- |
| 1. Functional development | Complete | Planned dock features accepted on the desktop |
| 2. Distribution compatibility | Validated | Shared sources built and exercised across KDE Plasma Wayland distributions |
| 3. Code cleanup and consolidation | In progress | Existing behavior and saved configurations survive the reorganization |
| 4. Packaging | Planned | Installable artifacts validated on their target systems |
| 5. First release | Planned | User documentation, compatibility matrix and GitHub release ready |

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

**Automated validation.** The regression suite has 15 CTest entries. GitHub
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

The first change groups capsule path construction, exterior stroke generation and
SVG serialization in `src/capsulegeometry.cpp`. Surface placement and pointer
regions remain in `src/geometry.cpp`. The next review covers pointer tracking
and visibility decisions in `DockController`.

Validate the changes with CTest, CI and a staged installation. Before starting
packaging, recheck the affected interactions on CachyOS and the reference
desktops, including the Debian baseline. Give particular attention to saved
profile migration, live resizing, pointer tracking, previews and blur after
hide/reveal. [Regression scenarios](testing.md)

Retain the indicator parity checklist during consolidation:

- macOS, Plasma and Custom modes, native group symbols and independent task frames.
- Per-state segment dimensions, edge placement, color sources and separate unfocused colors.
- Opacity, minimized-window handling and indicator animations.

## 4. Packaging

Prepare native packages for Arch, Fedora, Debian, Ubuntu and openSUSE from the
shared sources. Test installation, launch, upgrade and removal for each target.
The dock uses private Qt GUI headers, so verify each binary against the Qt
build shipped on its target.

For Bazzite, prototype a lightweight AppImage using the host KDE libraries.
Validate library compatibility and Wayland integration on Bazzite before
publishing it. The tested Distrobox procedure remains available. Evaluate
other immutable distributions individually.

## 5. First release

Finish the user guide and installation, upgrade and uninstallation instructions
for source builds and published packages. Publish a compatibility matrix with
tested versions, installation method and the scope of manual and automated
checks. Prepare the first GitHub release with its tag, release notes and
verified artifacts.

The [development history](development-history.md) retains the original PR
notes, earlier plans and the [indicator parity checklist](development-history.md#final-version-parity-requirement).
