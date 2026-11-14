# Licensing and provenance

Project-owned sources are offered under GNU GPL version 2 **or any later version**
(`GPL-2.0-or-later`). The repository LICENSE contains the complete GPLv2 text;
source notices and README establish the later-version option.

## Imported source

Donor repository: [SarbaLabs/plasma-macos-dock](https://github.com/SarbaLabs/plasma-macos-dock)

Donor commit: `cd5fa9d9efc31a08bbe4c6d346b46771dec4acca` (master after PR #4).

| Destination | Source at donor commit | Treatment | License |
|---|---|---|---|
| `qml/CapsuleGlow.qml` | `contents/ui/CapsuleGlow.qml` | Copied with SPDX notice | GPL-2.0-or-later |
| `qml/code/CapsuleGeometry.js` | `contents/ui/code/CapsuleGeometry.js` | Rounded geometry subset; removed unused separator functions | GPL-2.0-or-later |

The donor fork originates from [Matt-Anis/plasma-macos-dock](https://github.com/Matt-Anis/plasma-macos-dock)
and contains KDE contributions. Preserve original file-specific attribution when
importing further files. This first stage does not copy Fancy Tasks NG indicator
code, icon artwork, KDE task delegates, the native menu backend, or the blur plugin.
Those require separate provenance entries if ported later.

## Protocol and libraries

- KDE `kde-screen-edge-v1.xml`: MIT-CMU, copyright Vlad Zahorodnii (2023).
  Generated at build time from the installed plasma-wayland-protocols package;
  do not strip its generated license notices. No local protocol fork is maintained.
- LayerShellQt: KDE library, component notices include LGPL-2.1-only OR LGPL-3.0-only
  OR LicenseRef-KDE-Accepted-LGPL. Used as an installed dependency.
- Qt, Kirigami and KDE TasksModel: use installed libraries/modules and their own
  licensing. No library source or icon theme is bundled in this repository.
- Theme icons are resolved at runtime; the desktop entry references a system icon.

The GPL-2.0-or-later option is intentional. A distributed combined executable may
need to be conveyed under GPLv3 when using LGPLv3-only dependencies; do not describe
the complete dependency combination as GPLv2-only. Audit the actual dependency and
asset licenses before distributing binary packages. Keep corresponding source and
build/install scripts available under the applicable terms.

## Native context menus

- `src/applicationmenubackend.{h,cpp}`: imported from the same donor commit
  `cd5fa9d9efc31a08bbe4c6d346b46771dec4acca`, corresponding paths under `src/`.
  Focused KDE taskmanager backend adaptation, GPL-2.0-or-later, Eike Hein notices
  preserved. No shortcut-registration or plasmoid backend is instantiated.
- `qml/ContextMenu.qml`: standalone adaptation of KDE plasma-desktop
  `applets/taskmanager/qml/ContextMenu.qml` (commit `f1d3689715c0d65376b78d4b649b437dee092d98`, consulted 2026-11-14).
  Eike Hein and Kai Uwe Broulik notices preserved, GPL-2.0-or-later. Uses installed
  PlasmaExtras.Menu/MenuItem rather than copying their Qt Widgets implementation.
- Standard labels reuse installed `plasma_applet_org.kde.plasma.taskmanager`
  translations with their original contexts. Project-specific labels use the
  `plasma-next-dock` KI18n catalog; its French PO is included.

The native integration tests `tests/applicationmenutest.cpp` and
`tests/menulaunchprobe.cpp` are also adapted from the same donor commit and paths,
GPL-2.0-or-later. The optional-plasmoid bridge test was removed because this host
links its own backend directly. No upstream translation catalog is bundled;
standard translations are provided by the installed KDE packages.

## Window previews

`qml/WindowThumbnail.qml` adapts `contents/ui/PipeWireThumbnail.qml` from donor
commit `cd5fa9d9efc31a08bbe4c6d346b46771dec4acca` (SarbaLabs/plasma-macos-dock).
LGPL-2.0-or-later; Aleix Pol Gonzalez's 2020 notice is preserved. It uses installed
KPipeWire and TaskManager.ScreencastingRequest without copying their internals.
PlasmaCore.ToolTipArea and its themed interactive dialog are used as dependencies;
no tooltip implementation or theme artwork is copied.

## Advanced indicators

Donor: SarbaLabs/plasma-macos-dock commit
`cd5fa9d9efc31a08bbe4c6d346b46771dec4acca`:

- contents/ui/CustomIndicators.qml and IndicatorTaskState.qml: GPL-2.0-or-later;
  Vitaliy Elin (2025–2026) and SushiTrash (2025) notices retained. These already
  adapt the bounded-segment/state approaches of Fancy Tasks NG.
- contents/ui/GroupExpanderOverlay.qml: GPL-2.0-or-later, Eike Hein (2012–2013)
  notice retained. Theme artwork is loaded from installed KSvg/Plasma assets.
- contents/ui/NativeTaskIndicator.qml, code/IndicatorLogic.js and
  ConfigIndicators.qml (adapted as IndicatorsSettings.qml), plus
  tests/indicators/tst_indicators.qml: GPL-2.0-or-later.

No unrelated Fancy Tasks NG host/model code or theme artwork is imported. The
new DockIndicators composition and standalone settings persistence remain project
code. Native reveal animation uses KWindowEffects/KWin as installed dependencies,
not copied compositor implementation. Original licensing texts remain preserved.

## Capsule backgrounds

Donor: SarbaLabs/plasma-macos-dock commit
daf60631cbca7ae12b1a587bfff3a3fd7639a53e:

- contents/ui/LiquidGlassBackground.qml adapted as qml/CapsuleBackground.qml;
  GPL-2.0-or-later, Matt Anis (2024) notice retained. Removed optional plasmoid
  plugin discovery; kept tint, rounded layers, gloss and bounded glow composition.
- src/dockbluritem.cpp/.h informed the GUI-thread, queued restoration and effect
  cache reset in the host-specific src/backgroundeffects.cpp/.h; original
  Matt Anis notice retained. No PanelView or Plasma theme observer is imported.

KWindowEffects is used as an installed KDE Frameworks API; no KWin implementation
or theme artwork is copied. Existing license texts remain unchanged.
