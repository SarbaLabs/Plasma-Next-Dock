# Plasma Next Dock

An experimental standalone dock for **KDE Plasma on Wayland**, developed by
[SarbaLabs](https://github.com/SarbaLabs/Plasma-Next-Dock).

The project grows out of [our Plasma macOS Dock fork](https://github.com/SarbaLabs/plasma-macos-dock).
Its goal is to let icons grow beyond the visible capsule without a larger invisible
Plasma panel causing premature window avoidance.

**Status: early standalone dock with persistent settings, not yet feature-complete.**
The foundation, settings, launcher reordering, adaptive sizing and scrolling were
validated by the maintainer on CachyOS, including native context menus. Grouping, interactive previews and their corrected placement have also been accepted.
Advanced indicators, stable magnification anchors and native reveal animation have also been accepted.
Background modes, blur, spacing and hover controls have also been accepted. Application audio, media controls and status overlays have been accepted. Behavior settings, the separator and immediate wheel cycling have been accepted. Icon bounce, hover highlighting and the active indicator palette have been accepted. It does not modify Plasma or KWin, install a
KWin effect, replace a panel, or touch the existing plasmoid configuration.

## What this prototype implements

- A separate Qt Quick window using LayerShellQt, anchored to any screen edge.
- Independent drawing bounds, rounded capsule collision geometry and mouse input region.
  The empty gap to the screen edge accepts hover so edge-only recall can re-hide
  correctly; interior drawing margins remain click-through.
- Continuous icon magnification (40 logical pixels and 1.5× by default).
- Running tasks and persistent pinned launchers through KDE's native TasksModel;
  clicking a single task delegates activation/launching to KDE. Application windows
  are grouped and filtered to the current desktop and activity. Clicking a group
  opens its window selector by default. Collision tracking remains independently ungrouped.
- A Behavior page for native grouping/sorting, mouse actions, screen/desktop/activity
  filters, task direction, attention reveal and the pinned/unpinned separator.
  Overflow scrolling takes priority over optional group-window cycling.
- Native Plasma tooltips anchored toward the desktop interior, with window titles,
  activate/close controls and on-demand KDE PipeWire thumbnails.
- Window avoidance based on the **visible capsule**, not the transparent canvas.
- Native KWin screen-edge recall through `kde-screen-edge-v1`, without unmapping
  the window. If the extension is unavailable, the dock stays visible.
- Solid, Liquid Glass and edge-relative Gradient backgrounds, each with optional KWin blur.
  Four independent signed corner radii shape the background, glow and native blur.
  Optional application-color glow stays inside the capsule.
- macOS, Plasma and Custom running indicators, independent native group/decorations,
  and native KWin reveal animation.
- A normal configuration window, saved launcher order, and native Plasma context menus:
  desktop-entry actions, KDE Places, activity-filtered recent files, window operations,
  desktops/activities, supported media controls, Pin/Unpin, Configure and Quit.
- Standard menu translations from KDE, plus a project catalog (French included).
  Native Plasma menus use the system widget style; no forced transparency or colors.
- Adaptive icon/capsule sizing and wheel/trackpad scrolling when the minimum size is reached.
- A harmless `--demo` mode with five inert icons, independent of running applications.

Configurable launch/attention bounce and the native **Test Bounce Animation** action
are available under Configure → Icons and animations → Icon bounce. See [bounce settings and
validation](docs/bounce.md) and the remaining [roadmap](docs/roadmap.md).

## Multiple docks and screens

Right-click a dock and choose **Configure Plasma Next Dock…** to open its
settings. Use the dock selector above the section sidebar to switch between docks. **Add
dock** creates and selects a fresh profile on a free edge. Choose its screen and
edge, edit its settings and click **Apply** before switching profiles. Pinned
applications and their order are saved immediately. **Remove dock** asks for
confirmation. One dock stays available for opening settings.

The existing configuration becomes Dock 1 on upgrade. Each dock has its own
launchers, appearance, task filters, indicators and behavior. Session startup
applies to the whole collection. Two docks can share a monitor on different
edges. Select a named output to keep a dock there, or choose **Primary screen**
to follow the primary output. A disconnected dock resumes when the output name
returns. If every assigned screen is missing, the first dock temporarily uses
the primary output. A primary-output change that brings two docks to the same
edge gives the first dock priority until their positions separate.

## Adding applications and external drops

Configure → Applications and sorting → Add an application opens a searchable list
of installed applications. Names and icons come from KDE's application catalog.
Launcher changes are immediate; duplicates are not added.

Drag an installed application from a launcher/file manager onto the dock to pin it.
The drop position selects a slot relative to pinned applications in manual sorting;
other sort modes retain their own ordering. Drop documents or supported URLs onto
an application to ask KDE to open them with it. Hold a document over a running task
for 650 ms to activate its window without minimizing it. For a group, this opens its window previews.
Keep holding the document and hover a preview for 350 ms to bring that window
forward. Keep the document over the previews to choose another window. Leaving
the preview area closes it so you can drop the document in the application.

If the dock overflows, hold the document or application launcher near either end
to scroll toward hidden icons. Move away from the end to stop and choose the
target. This also works at the top and bottom of a vertical dock.

Only installed application launchers can be pinned by drop. Mixed launcher/document
drops and uninstalled .desktop files are rejected. No file is moved or copied.
See [external drop architecture and acceptance](docs/external-drops.md). The maintainer validated these features on CachyOS Wayland over several days
without reported problems. The wider source/output matrix remains a regression
checklist, not a claim of universal compatibility.

## Task behavior

Open Configure → Behavior. Existing grouping, desktop/activity filters and manual
sorting remain the defaults. New click and wheel behaviors are opt-in. Reversing
the task direction also places unpinned tasks at the opposite end; the separator
stays between sections. Automatic sorting disables manual icon dragging.
See [behavior settings and desktop checks](docs/behavior.md).

## Capsule backgrounds

Open Configure → Appearance. Choose a fixed
color or a KDE palette role for the fill and exterior border. Gradient has
independent desktop-side and screen-edge colors and opacities. Move the midpoint
toward the screen edge to give the desktop-side color more space. Solid supports
0–100% opacity. Liquid Glass places its bright reflection on the desktop side. Border width
and opacity are independent of the fill.

For a bottom dock that joins the desktop edge, set the distance to zero, give
the upper corners positive radii and the lower corners negative radii. The
lower corners flare out along the edge. The exterior border remains visible
around the exposed sides. Older profiles inherit their saved radius on all four corners.
Spacing follows the dock orientation and participates in adaptive sizing.

The native effects are built into this executable, not a plasmoid plugin. No new
dependency, system configuration change or Plasma Shell restart is required.
If KWin's blur effect is unavailable, tint/gloss remain visible without blur.
See [background architecture and testing](docs/backgrounds.md).

The optional hover glow follows the pointer and uses the hovered icon's color.
Its radius can track the magnified icon size (0 = automatic) or use a fixed
1–256 logical pixels. Intensity scales the selected opacity (up to 200%);
the defaults are 100% intensity and 30% opacity. Each dock saves its own values.

## Keyboard navigation

Press **Meta+Alt+Space** to reveal and focus the selected dock (or the first
available dock). Press the shortcut again during navigation to cycle through
available docks. You can reassign **Focus Plasma Next Dock** in KDE System
Settings → Keyboard → Shortcuts.

Use Left/Right on a horizontal dock or Up/Down on a vertical dock. Home and
End select the first and last icon in visual order. Enter or Space activates
the selected task or launcher; for a group it opens its window previews. Use the arrows along the
dock to choose a preview (Home/End jump to either end), then Enter or Space to
activate that window. Escape returns to the group icon. Menu or Shift+F10 opens the selected icon’s
context menu. Escape closes the menu and returns to that icon. A second Escape
exits navigation. Outside this mode the dock requests no keyboard focus.

## Visibility and alignment

Each dock can use **Always visible** to reserve its resting thickness plus the
edge gap and exterior border. Maximized windows leave this strip free across
the selected screen edge. Hover magnification does not move those windows.
**Auto hide** recalls the dock at its edge; **Dodge windows** hides it on
overlap; **Windows go below** keeps the dock above normal windows without
reserving space. Existing profiles retain their previous dodge or overlay behavior.

Horizontal docks can align left, center or right. Vertical docks can align top,
center or bottom. With either end selected, the capsule and icons grow toward
the other end of the screen during magnification. The alignment margin offsets
that end along the edge, for example below a top panel. Each dock remembers
its margin; centered docks ignore it.

## Build and install on CachyOS / Arch

Dependencies (the KDE runtime packages are usually already installed):

```bash
paru -S --needed base-devel cmake qt6-base qt6-declarative qt6-shadertools qt6-wayland qt6-svg plasma-pa \
    layer-shell-qt plasma-wayland-protocols plasma-workspace plasma-desktop kirigami breeze-icons \
    ki18n kio kservice knotifications plasma-activities-stats plasma-integration kpipewire kglobalaccel kwindowsystem gettext
```

Qt **6.8 or newer** is required. Building uses Qt's private GUI headers for the
native Wayland surface adapter; rebuild after a Qt upgrade that changes them.

To install the current main branch:

```bash
mkdir -p ~/git
cd ~/git
git clone --branch main https://github.com/SarbaLabs/Plasma-Next-Dock.git
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
- **Applications and sorting** shows pinned apps by name and icon. The sort selector
  applies immediately to the selected dock. Drag a handle or use the up/down
  buttons in manual mode. Automatic modes use the task model's visual order;
  returning to manual restores the saved pin order. Add and remove work in every mode.
- The dock stays visible while its menu or configuration window is open.

Settings live in `$XDG_CONFIG_HOME/plasma-next-dock.ini`, normally
`~/.config/plasma-next-dock.ini`. Defaults preserve the initial prototype appearance:
40 px icons, 1.5× zoom, 8 px spacing, 10 px radius, bottom/primary output, glow off,
dodge on and no pinned apps.

To start the dock with your KDE Plasma Wayland session, open **Configure →
Position and visibility**, check **Start Plasma Next Dock at login**, and click
**Apply**. The option starts off disabled. Uncheck it and apply to remove the
login entry. Closing the settings window discards an unapplied change.
The user entry lives in `$XDG_CONFIG_HOME/autostart` (normally
`~/.config/autostart`) and links to a template under the installation prefix.
Running `./install.sh` again preserves the choice. A login launch reuses the
usual dock configuration and exits successfully if the dock is already running.

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

Tasks with audio offer Mute. In More, you can change grouping for one application or use Kill to force a blocked process to quit.

The dock uses `PlasmaExtras.Menu` / `MenuItem`, the same components as Plasma's
Icons-Only Task Manager. These wrap Qt Widgets menus, so appearance comes from
KDE platform integration and the selected application widget style/color scheme.
They are not a custom copy of the Plasma SVG background. Opacity, shadows and
corners are not forced by this project; a screenshot alone cannot establish which
menu implementation another widget uses. Compare the two in the same session.

KDE section headings and window commands explicitly use the task-manager
translation catalog. Application action names come from the installed desktop
entries; Places come from your KDE bookmarks. Project-specific menu commands use
our own catalog, with French included and English fallback. The settings window also uses this catalog, including French translations.

See [menu architecture and limitations](docs/context-menus.md) and
[manual validation](docs/testing.md). No Plasma Shell restart is needed: quit and
restart **Plasma Next Dock** after running `./install.sh`.

## Grouped windows and previews

Hover an icon to show the native Plasma tooltip toward the interior of the screen.
A pinned launcher without a window shows its name. Running windows show titles,
activation and close controls; clicking a grouped application opens the selector
immediately. The native group symbol can be enabled independently of the running-indicator mode.
Previews scroll when the group exceeds the available area. Hover a preview card
to see that window on the desktop while KWin fades the other windows. Moving to
another card changes the highlighted window, and leaving the cards restores the
desktop. Click a card to activate its window. This per-dock option is enabled
by default under **Configure → Behavior → Previews and media** and uses KWin's Highlight
Window effect when available.

Live thumbnails use KDE's `ScreencastingRequest` and KPipeWire under KWin Wayland.
Only visible, non-minimized cards request capture, and hiding the popup releases
it. A missing/minimized thumbnail retains an application icon and window title.
Install `kpipewire` and restart the dock after updating. No Plasma restart or KWin
configuration change is required. The installed desktop file declares the capture
interface for older KWin permission checks.

[Preview architecture and manual checks](docs/window-previews.md) describe the
headless test limitations. Three-mode indicator customization from our older dock is now available; remaining
parity work stays tracked explicitly in the roadmap.

## Icon colors

Under **Icons and animations**, each dock can use original icon colors
(the default) or grayscale. Enable **Tint grayscale icons** to select a fixed
color or a system palette role. Tint saturation ranges from 0% (pure grayscale)
to 100%. The filter applies to launcher and task artwork, preserving transparency
and leaving status badges and indicators in their configured colors.

## Advanced indicators and reveal animation

The **Indicators** section offers macOS (default), native Plasma theme and
Custom modes. Custom indicators support dots, a shared line or individual dashes;
state-specific sizes, up to eight window segments, roundness, spacing,
accent/icon/custom colors, separate unfocused color, opacity and minimized-window
desaturation. Settings persist when switching modes. A live configuration preview
shows six example windows. No unsupported overflow + is included.

The native group symbol and Plasma task decorations have independent Mode default /
Enabled / Disabled controls. Mode default enables them in Plasma mode and keeps
them off in macOS/Custom. The provisional numeric group label is replaced by this
optional native symbol. Existing macOS running dots retain their geometry/colors.

The dock always requests KWin's native Sliding Popups effect for hiding and reveal. It uses the system effect and animation speed; no global
settings are changed. If the effect is disabled/unavailable, edge recall still
works immediately. Wayland's slide protocol exposes no per-window duration, so
there is no misleading local duration slider and no competing QML animation.

See [indicator and animation architecture](docs/indicators.md) for defaults,
performance limits and desktop acceptance checks.

## Audio, media and application status

The **Behavior** section controls hover previews, desktop window highlighting, the audio indicator,
click-to-mute, media/volume controls, application counters and progress. These
options default to enabled and are saved independently. Disabling hover previews
keeps the application title and any supported media controls; clicking a group
still opens its window selector.

Audio uses KDE's plasma-pa model (including PipeWire's PulseAudio compatibility).
Click the speaker badge to mute/unmute the application's matched streams. Preview
volume controls preserve relative stream volumes and are limited to 100%. Media
buttons use the application's MPRIS player and its advertised capabilities.
Counters/progress use the installed task manager's SmartLauncherItem and honor its
notification settings and application support. No independent tracking is added.

The runtime needs `plasma-pa` and `plasma-desktop` in addition to the existing
Plasma packages. Restart only Plasma Next Dock after `./install.sh`.
See [application status architecture and validation](docs/application-status.md).
