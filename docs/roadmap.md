# Development status and roadmap

## 2026-11-13 — Standalone foundation

The maintainer created SarbaLabs/Plasma-Next-Dock and authorized initial development,
reuse of suitable Plasma macOS Dock components, and project documentation.
The working branch is `feature/standalone-prototype`; target branch is `main`.

Implemented: independent layer-shell host, separate geometries, real KDE task model,
initial task activation, demo mode, four edges, screen selection, continuous zoom,
bounded optional glow, corner radius, window-avoidance controller and native edge
adapter. User-local build/install/uninstall scripts and regression tests accompany it.

**Not yet accepted on the maintainer's KWin desktop.** See docs/testing.md for the
actual scope of automated evidence. This is a prototype to validate architecture,
not feature parity with Plasma macOS Dock and not a replacement recommendation.

## Next gate: prove the architecture

- Check actual layer placement, input passthrough, overlap and edge recall on CachyOS.
- Check task activation and launchers with the actual KDE model and installed apps.
- Test all edges, multiple output origins, fractional scale, fullscreen policy,
  interaction with existing panels and reveal/leave sequences.
- Resolve any platform/lifecycle findings before adding more features.

## Subsequent stages, not implemented yet

1. Persistent settings, configuration window, clean quit controls and an explicitly
   enabled autostart option. Decide whether to host existing Plasma UI components
   or adapt them behind a dedicated application interface.
2. Native application context menus, Places/recents and durable Pin/Unpin using
   the existing focused backend, without instantiating KDE's shortcut-registering backend.
3. Grouped tasks, interactive previews, keyboard navigation, drag/drop and badges.
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
