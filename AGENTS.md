# Development guidance

- Communicate with the maintainer in French. Keep code, comments, source UI text,
  docs, commits and PRs in English. Use Qt/KDE translation mechanisms.
- Work exclusively in SarbaLabs/Plasma-Next-Dock; PRs target main. Do not alter the
  separate plasma-macos-dock repository, Plasma configuration or compositor binaries.
- Do not merge, publish a release, create autostart entries or install into system
  directories without explicit authorization. Prefer ./install.sh; user checkouts
  are under ~/git and CachyOS package installation uses paru.
- This is a standalone host, not a plasmoid and not a KWin binary effect. Keep
  drawing space, input region and dodge geometry independent.
- Keep the prototype fail-open: do not hide if native edge recall is unavailable.
  Never unmap the QWindow to implement native edge hiding.
- The model used for collision must be ungrouped, filtered by current desktop and
  activity, and ignore launchers/minimized windows. Coalesce model notifications;
  never poll all windows every frame.
- Hover inhibits dodge. Do not feed animated task positions back into their own
  zoom bindings; update the logical pointer index only from pointer input.
- Keep interface-private Wayland code isolated in screenedge.cpp. Test its lifecycle
  on KWin after Qt/Plasma upgrades. Qt private GUI headers must match installed Qt.
- Preserve GPL-2.0-or-later and original notices on imported code. Record donor
  commits/files in docs/licensing.md before importing additional components.
- Preserve roundToIconSize:false. The glow must use the same rounded geometry as
  the capsule and remain optional with no color extraction when disabled.
- Run CTest, staged installation and QML checks. Do not describe offscreen tests as
  live Wayland verification. Update docs/testing.md and docs/roadmap.md with evidence.
- Consult docs/architecture.md before introducing settings, native menus or blur.
  Port complete coherent features instead of copying the old plasmoid wholesale.

- Keep settings under the unique plasma-next-dock.ini path; demo/smoke tests must
  never read/write the maintainer's configuration. Use native TasksModel pin APIs.
- Select layer-shell per dock window, never process-wide: the settings window must
  remain a keyboard-capable normal window. Retire old host/edge state before
  recreating a surface on output or edge changes.

- Keep native popup positioner compatibility in PopupAnchor. Recent Qt derives
  Wayland menu placement from the parent control rectangle; popup(x,y) alone is
  insufficient. Recheck the internal property contract after Qt upgrades.
- Installed desktop entries must use the installed executable's quoted absolute
  path; the host portal's PATH may not include ~/.local/bin.
