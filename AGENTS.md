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

- Native context menus use PlasmaExtras.Menu/MenuItem under QApplication. Do not
  replace them with painted Qt Quick menus or force opacity/style/palette. KDE
  standard labels need the explicit task-manager catalog and original context;
  dock-specific labels belong to plasma-next-dock and po/. Keep English fallback.
- Keep application launching in KIO with structured QUrls. Never concatenate shell
  commands. Preserve KDE history privacy and activity filtering. Target window
  actions through MenuTarget's persistent model index, never a saved row number.

- Group presentation and collision models are distinct: never enable grouping on
  the collision model. Window previews must target persistent child indexes.
- Use Plasma ToolTipArea with explicit edge location for inward native tooltips.
  Its shared mainItem is temporarily reparented during owner changes: never clear
  its newly selected model synchronously on that transient detach.
- Capture only visible preview cards and release streams on dismissal. Preserve
  icon/title fallback. Do not weaken compositor permissions to obtain thumbnails.
- Preserve the final indicator parity checklist in docs/roadmap.md; the current
  simple dot/count is not the final customization system.

- LayerSurfacePosition supplies the known layer-shell origin to Qt's client-side
  geometry; QWindow::setPosition alone is normalized by Qt Wayland. Keep its GUI
  private adapter per-window, event-driven and size-preserving. Never change Qt's
  global fixed-position policy or move the dock surface to position a tooltip.

- Indicator geometry must not feed back into layout or dodge. Keep at most eight
  segment delegates and event-driven bounded child state; share ImageColors with
  glow and keep extraction lazy. Preserve independent native decoration controls.
- Reveal animation uses KWindowEffects slide hints and KWin's system duration. The
  Wayland protocol has no per-window timing; do not add a fake duration setting,
  global compositor changes, or a competing QML hide/show animation.
- Settings QML uses KI18n through its configuration engine context. Keep source
  strings English, update Messages.sh inputs and maintain the French PO catalog.

- BackgroundEffects is the sole native effect owner for the standalone window.
  Reuse the existing radius setting and controller capsule signal; never blur the
  full canvas/edge corridor or enable an empty region. No PanelView hooks, render
  thread effect calls or periodic restoration loops. See docs/backgrounds.md.
