# Plasma Next Dock

An experimental standalone dock for **KDE Plasma on Wayland**, developed by
[SarbaLabs](https://github.com/SarbaLabs/Plasma-Next-Dock).

The project grows out of [our Plasma macOS Dock fork](https://github.com/SarbaLabs/plasma-macos-dock).
Its goal is to let icons grow beyond the visible capsule without a larger invisible
Plasma panel causing premature window avoidance.

**Status: early standalone dock with persistent settings, not yet feature-complete.**
The foundation, settings, launcher reordering, adaptive sizing and scrolling were
validated by the maintainer on CachyOS. Native context menus now need desktop validation. It does not modify Plasma or KWin, install a
KWin effect, replace a panel, or touch the existing plasmoid configuration.

## What this prototype implements

- A separate Qt Quick window using LayerShellQt, anchored to any screen edge.
- Independent drawing bounds, rounded capsule collision geometry and mouse input region.
  The empty gap to the screen edge accepts hover so edge-only recall can re-hide
  correctly; interior drawing margins remain click-through.
- Continuous icon magnification (40 logical pixels and 1.5× by default).
- Running tasks and persistent pinned launchers through KDE's native TasksModel;
  clicking a task delegates activation/launching to KDE. Tasks are ungrouped and
  filtered to the current desktop and activity.
- Window avoidance based on the **visible capsule**, not the transparent canvas.
- Native KWin screen-edge recall through `kde-screen-edge-v1`, without unmapping
  the window. If the extension is unavailable, the dock stays visible.
- Solid capsule, configurable corner radius and optional bounded application-color glow.
- A normal configuration window, saved launcher order, and native Plasma context menus:
  desktop-entry actions, KDE Places, activity-filtered recent files, window operations,
  desktops/activities, supported media controls, Pin/Unpin, Configure and Quit.
- Standard menu translations from KDE, plus a project catalog (French included).
  Native Plasma menus use the system widget style; no forced transparency or colors.
- Adaptive icon/capsule sizing and wheel/trackpad scrolling when the minimum size is reached.
- A harmless `--demo` mode with five inert icons, independent of running applications.

This first stage intentionally does **not** yet port window previews, grouping,
System Blur/Liquid Glass, bounce, badges or the full indicator system. Those remain
available in Plasma macOS Dock while this new host is validated. See the [roadmap](docs/roadmap.md).

## Build and install on CachyOS / Arch

Dependencies (the KDE runtime packages are usually already installed):

```bash
paru -S --needed base-devel cmake qt6-base qt6-declarative qt6-wayland qt6-svg \
    layer-shell-qt plasma-wayland-protocols plasma-workspace plasma-desktop kirigami breeze-icons \
    ki18n kio kservice knotifications plasma-activities-stats plasma-integration gettext
```

Qt **6.8 or newer** is required. Building uses Qt's private GUI headers for the
native Wayland surface adapter; rebuild after a Qt upgrade that changes them.

For the native context menu development branch:

```bash
mkdir -p ~/git
cd ~/git
git clone --branch feature/native-context-menus https://github.com/SarbaLabs/Plasma-Next-Dock.git
cd Plasma-Next-Dock
./install.sh
```

The script builds, runs the available tests, and installs the executable and its
own application launcher and translation catalog under **`~/.local`**. It requires no `sudo`, creates no
autostart entry and does not restart Plasma Shell. Change the destination only
when needed with `PLASMA_NEXT_DOCK_PREFIX=/your/prefix ./install.sh`.

To update an existing checkout on the same branch:

```bash
cd ~/git/Plasma-Next-Dock
git pull --ff-only
./install.sh
```

## Try it without replacing your dock

Start with the inert demonstration on a free edge, away from existing panels:

```bash
~/.local/bin/plasma-next-dock --demo --edge left --glow
```

Stop it with **Ctrl+C in the launching terminal**. You can also right-click the dock and choose **Quit Plasma Next Dock**. Then try live tasks:

```bash
~/.local/bin/plasma-next-dock --edge left --glow \
    --launcher applications:org.kde.dolphin.desktop \
    --launcher applications:org.kde.konsole.desktop
```

`--demo` does not launch apps or dodge windows. Use live mode to test overlap/recall.
Keep the launch terminal accessible while evaluating edge behavior. A normal
application must overlap the **capsule**, not merely the empty canvas above it.
The dock stays visible while hovered and waits 180 ms after leaving before hiding.

Useful options:

| Option | Default | Purpose |
|---|---|---|
| `--edge bottom\|top\|left\|right` | bottom | Screen edge |
| `--screen NAME` | primary output | Choose an output from `--list-screens` |
| `--icon-size 40` | 40 | Resting size, 24–96 logical pixels |
| `--zoom 1.5` | 1.5 | Magnification, 1–2.5 |
| `--radius 10` | 10 | Capsule radius, 0–96 logical pixels, clamped to its size |
| `--spacing 8` | 8 | Capsule distance from physical screen edge, 0–128 logical pixels |
| `--settings` | closed | Open the configuration window |
| `--glow` | disabled | Enable bounded application-color glow |
| `--no-dodge` | dodge enabled | Keep the dock visible |
| `--launcher URL` | none | Repeat for each desktop-entry launcher |
| `--demo` | disabled | Inert sample icons, no window avoidance |

The configured icon size is a preferred size. Long task lists automatically reduce
icons, spacing and capsule thickness to fit the selected output, reserving room
for magnification. Settings are never overwritten by this adaptation. At the
24 logical pixel minimum, lists that still overflow can be scrolled with a mouse
wheel or touchpad (on horizontal and vertical docks). Removing tasks restores the
preferred size. Only the local magnification around the pointer is reserved (at most two full-icon
zoom equivalents), rather than full zoom for every application. Overlapping
animation tails share that same bounded budget. Settings are not
imported from the old dock.

## Configure and pin applications

Right-click an icon or the capsule and choose **Configure Plasma Next Dock…**.
The configuration window can also be opened at startup with `--settings` (if a live
dock is already running, use its menu instead of starting a second process).

- Screen, edge, icon size, magnification, distance from the edge, corner radius,
  glow and window avoidance are saved with **Apply**. Closing discards unapplied
  appearance edits. Screen/edge changes briefly recreate only the dock surface.
- The distance from the edge accepts **0–128 logical pixels**, default 8. The
  pointer corridor follows it; window avoidance still uses only the visible capsule.
- Right-click a running app to pin it; right-click a pinned app to unpin it.
  The native KDE model handles application identity and launcher matching.
- Drag icons within the dock to reorder them. Moving starts after the standard
  pointer threshold, suppresses activation and saves pinned order when released.
  KDE keeps pinned and unpinned tasks in their respective groups; only pinned
  application order persists after restart.
- **Pinned applications** lists saved launchers in order. Use **Up**, **Down** or
  **Remove**; these actions save immediately. You can add an installed application's
  desktop entry ID (for example `org.kde.dolphin.desktop`) without opening it first.
  This initial UI is not a searchable application catalog; unavailable desktop
  entries may not produce a task until their application is installed.
- The dock stays visible while its menu or configuration window is open.

Settings live in `$XDG_CONFIG_HOME/plasma-next-dock.ini`, normally
`~/.config/plasma-next-dock.ini`. Defaults preserve the initial prototype appearance:
40 px icons, 1.5× zoom, 8 px spacing, 10 px radius, bottom/primary output, glow off,
dodge on and no pinned apps. No background service or autostart is created.

CLI geometry/launcher options override saved values for the current session;
explicitly applying settings or changing pins saves the current values. Demo and
smoke modes ignore saved settings and never write configuration. `--demo` therefore
lets you experiment without overwriting your real dock setup.

## Important prototype limits

- The KDE edge protocol is an internal extension, not a stable cross-desktop API.
  This project targets KWin; it does not claim support for other compositors.
- Edge recall follows KWin's policy. The recalled span follows the host surface,
  which can be wider than the capsule to accommodate zoom. This does not expand
  the collision area used to decide when to hide.
- Collision uses the capsule's rounded geometry, not individual transparent icon
  pixels. Hover temporarily inhibits avoidance, including when icons enlarge.
- The top layer is for normal desktop windows; behavior around fullscreen apps,
  other panels, gestures and shared monitor edges needs desktop validation.
- If the selected output is unavailable, the dock uses the primary output while
  retaining the saved output preference. Removing the current output recreates the dock
  on an available primary output. There is one live instance per user; demo instances are separate.
- Automated offscreen tests cannot prove KWin recall, input passthrough, real
  application activation or fractional-scale compositor behavior.

See [testing](docs/testing.md) for the actual evidence and manual checklist.

## Uninstall

Stop the process, then run:

```bash
cd ~/git/Plasma-Next-Dock
./uninstall.sh
```

Only this project's executable and desktop entry are removed. Your settings file is
retained so a later installation can reuse it. If you used a
custom prefix, supply the same `PLASMA_NEXT_DOCK_PREFIX`. No Plasma reset is needed.

## Development and licensing

- [Architecture](docs/architecture.md)
- [Development status and roadmap](docs/roadmap.md)
- [Tests and desktop acceptance](docs/testing.md)
- [Licenses, provenance and reuse](docs/licensing.md)
- [Contributor instructions](AGENTS.md)

Project-owned code is licensed under **GNU GPL version 2 or any later version**
(`GPL-2.0-or-later`). See [LICENSE](LICENSE). Preserve component-specific licenses
and copyright notices. This repository is developed with AI assistance and tested
by its maintainer; test limitations are recorded explicitly.

## Native context menus and language

The dock uses `PlasmaExtras.Menu` / `MenuItem`, the same components as Plasma's
Icons-Only Task Manager. These wrap Qt Widgets menus, so appearance comes from
KDE platform integration and the selected application widget style/color scheme.
They are not a custom copy of the Plasma SVG background. Opacity, shadows and
corners are not forced by this project; a screenshot alone cannot establish which
menu implementation another widget uses. Compare the two in the same session.

KDE section headings and window commands explicitly use the task-manager
translation catalog. Application action names come from the installed desktop
entries; Places come from your KDE bookmarks. Project-specific menu commands use
our own catalog, with French included and English fallback. This stage does not
translate the entire existing settings window.

See [menu architecture and limitations](docs/context-menus.md) and
[manual validation](docs/testing.md). No Plasma Shell restart is needed: quit and
restart **Plasma Next Dock** after running `./install.sh`.
