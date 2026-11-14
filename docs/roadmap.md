# Development status and roadmap

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
