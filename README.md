# Plasma Next Dock

An experimental standalone dock for **KDE Plasma on Wayland**, developed by
[SarbaLabs](https://github.com/SarbaLabs/Plasma-Next-Dock).

The project grows out of [our Plasma macOS Dock fork](https://github.com/SarbaLabs/plasma-macos-dock).
Its goal is to let icons grow beyond the visible capsule without a larger invisible
Plasma panel causing premature window avoidance.

**Status: first architectural prototype, not yet a replacement for the existing dock.**
It needs real KWin desktop validation. It does not modify Plasma or KWin, install a
KWin effect, replace a panel, or touch the existing plasmoid configuration.

## What this prototype implements

- A separate Qt Quick window using LayerShellQt, anchored to any screen edge.
- Independent drawing bounds, rounded capsule collision geometry and mouse input region.
  The empty gap to the screen edge accepts hover so edge-only recall can re-hide
  correctly; interior drawing margins remain click-through.
- Continuous icon magnification (40 logical pixels and 1.5× by default).
- Running tasks and optional command-line launchers through KDE's native TasksModel;
  clicking a task delegates activation/launching to KDE. Tasks are ungrouped and
  filtered to the current desktop and activity.
- Window avoidance based on the **visible capsule**, not the transparent canvas.
- Native KWin screen-edge recall through `kde-screen-edge-v1`, without unmapping
  the window. If the extension is unavailable, the dock stays visible.
- Solid capsule, configurable corner radius and optional bounded application-color glow.
- A harmless `--demo` mode with five inert icons, independent of running applications.

This first stage intentionally does **not** port advanced context menus, Places,
recents, window previews, grouping, drag-and-drop pinning, persistent settings,
System Blur/Liquid Glass, bounce, badges or the full indicator system. Those remain
available in Plasma macOS Dock while this new host is validated. See the [roadmap](docs/roadmap.md).

## Build and install on CachyOS / Arch

Dependencies (the KDE runtime packages are usually already installed):

```bash
paru -S --needed base-devel cmake qt6-base qt6-declarative qt6-wayland qt6-svg \
    layer-shell-qt plasma-wayland-protocols plasma-workspace kirigami breeze-icons
```

Qt **6.8 or newer** is required. Building uses Qt's private GUI headers for the
native Wayland surface adapter; rebuild after a Qt upgrade that changes them.

For the first prototype branch:

```bash
mkdir -p ~/git
cd ~/git
git clone --branch feature/standalone-prototype https://github.com/SarbaLabs/Plasma-Next-Dock.git
cd Plasma-Next-Dock
./install.sh
```

The script builds, runs the available tests, and installs the executable and its
own application launcher under **`~/.local`**. It requires no `sudo`, creates no
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

Stop it with **Ctrl+C in the launching terminal**. The first prototype deliberately
has no tray controller or quit context menu. Then try live tasks:

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
| `--glow` | disabled | Enable bounded application-color glow |
| `--no-dodge` | dodge enabled | Keep the dock visible |
| `--launcher URL` | none | Repeat for each desktop-entry launcher |
| `--demo` | disabled | Inert sample icons, no window avoidance |

Long task lists can be scrolled inside the drawing surface. Settings currently
come from command-line options and are not imported from the old dock.

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
- If the selected output is removed, the prototype exits rather than relocating
  unexpectedly. There is one live instance per user; demo instances are separate.
- Automated offscreen tests cannot prove KWin recall, input passthrough, real
  application activation or fractional-scale compositor behavior.

See [testing](docs/testing.md) for the actual evidence and manual checklist.

## Uninstall

Stop the process, then run:

```bash
cd ~/git/Plasma-Next-Dock
./uninstall.sh
```

Only this project's executable and desktop entry are removed. If you used a
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
