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
2. Native application context menus and Places/recents using
   the existing focused backend, without instantiating KDE's shortcut-registering backend.
3. Grouped tasks, interactive previews, keyboard navigation, external drops and badges.
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
