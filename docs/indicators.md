# Advanced indicators and native reveal animation

## Modes and compatibility

macOS is the default: the original four-pixel dot (scaled with adaptive fit) retains
its active/inactive colors, slot position and magnification behavior. Plasma mode
uses widgets/tasks FrameSvg prefixes for orientation and normal/focus/minimized/
attention/hover state. Disabling decorations retains only the native outward border
strip. Custom mode reuses the prior dock's bounded dot/line/dash renderer.

Native group symbols and task decorations use separate three-state settings:
0 = mode default, 1 = enabled, 2 = disabled. Mode default enables both only for
Plasma. The provisional numeric group label is replaced by the native symbol.
In macOS/Custom the symbol sits at the lane end to avoid centered indicators; in
Plasma it stays centered on the panel-facing side. Nothing changes the capsule,
collision bounds, icon size, frame spacing or window model.

Existing INI keys remain valid. New defaults are supplied automatically. Switching
modes retains all Custom values. Unknown keys (including obsolete indicatorOverflow)
are ignored; invalid colors/numbers are sanitized. No old plasmoid configuration
is imported automatically. ./install.sh still installs the complete executable,
embedded QML, desktop entry and translation catalog.

## Custom settings

| Setting | Default |
|---|---|
| Running indicators / state animations | On / on (120 ms) |
| Style | Dots |
| Position | Dock edge; override off |
| Edge distance / spacing | 2 / 2 logical px |
| Inactive length / thickness | 12 / 4 px |
| Active resize; length / thickness | On; 20 / 5 px |
| Hover resize; separate dimensions | Off; on, 24 / 6 px |
| Group dimensions | Off; 8 / 4 px |
| Corner roundness / thickness alignment | 100% / centered |
| Maximum segments | 4, configurable 1–8 |
| Highlight group active / dim inactive | On / on |
| Inactive opacity | 55% |
| Desaturate minimized | Off |
| Color source / custom color | Plasma accent / #3daee9 |
| Separate unfocused color | Off; #3daee9 when enabled |

Hover dimensions take precedence over active and grouped dimensions. Dots stay
circular; line lengths are shared across the visible segments, dashes use a length
per window. Geometry fits within the icon lane and available capsule padding, so
requested thickness can be clamped on small docks. No indicator changes task size.
The final visible segment represents an active child beyond the configured limit;
there is deliberately no additional custom overflow +. Unfocused color is applied
before opacity/desaturation, independently of minimized state.

## State and performance

IndicatorTaskState follows native TasksModel.activeTask and its parent to determine
the focused child. It coalesces model notifications and reads minimized state for
at most eight children. It does not traverse groups on pointer or animation frames.
CustomIndicators keeps its segment objects when hover/size/color changes. A lazy
ImageColors loader is shared with hover glow and enabled only when either feature
needs it. Missing icon color falls back to the live Plasma accent.

Native frames use installed KSvg theme elements, not approximated rectangles.
Frames are bounded along the task axis to avoid painting into the neighboring
slot. The existing rounded capsule, native preview origin adapter, context menus
and ungrouped collision model are unchanged.

## Reveal animation

KWin's Sliding Popups effect observes window hidden-state changes, including
layer-shell screen-edge recall, and supports reversal of an ongoing transition.
ScreenEdge sets the native KWindowEffects::slideWindow hint for the correct edge
with offset zero. The compositor animates the entire surface; local magnification
continues normally. Input corridor, edge activation and capsule-only avoidance are
not expanded or replaced. The window is never unmapped to implement dodge.

The persistent revealAnimation setting defaults to true. Turning it off removes
the dock's slide hint. If Sliding Popups is disabled/unavailable, normal immediate
hide/recall remains usable. No effect is enabled globally by the installer.

The Wayland slide protocol exposes location/offset but no per-window timing.
Duration therefore follows KWin's effect/system animation configuration. A local
speed slider, initially discussed, would have no supported effect and is omitted.
There are no custom QML slide/fade animations or periodic timers. KWindowEffects
restores its requests when the effect manager/surface returns; ScreenEdge also
invalidates its cached registration on its existing surface lifecycle events.

References: KDE kwin src/plugins/slidingpopups/slidingpopups.cpp and
src/layershellv1window.cpp; kwindowsystem src/platforms/wayland/windoweffects.cpp.
Licensing/provenance of reused indicator components is in licensing.md.

## Desktop acceptance (pending)

- Existing configuration: macOS dots unchanged; optional group symbol works on
  opening/closing windows; Plasma/Custom do not leave stale macOS dots.
- Native Plasma frames, strip-only mode, inactive/active/minimized/attention/hover
  states and theme changes. Explicit decoration/group toggles in every mode.
- Custom styles, every state dimension, active child inside and beyond the limit,
  separate unfocused color, accent changes, icon fallback, minimized desaturation.
- Small/large icons, magnification and adaptive fit, all four edges, fractional
  scaling, scrolling and multiple outputs. No clipping or layout oscillation.
- Apply/Close, mode switching and process restart preserve settings. French session
  translates settings and existing context menus; English remains source fallback.
- Hidden dock: edge reveal slides inward, leaving slides outward; rapid reversals,
  edge-only corridor use, animation toggle, disabled Sliding Popups, repeated
  overlap and recall. Confirm native speed feels right on the maintainer's system.
- Previews and their inward placement, grouped activation/close, drag reorder,
  Pin/Unpin, native actions/Places/recents and glow continue to work.

Headless tests check rendering geometry, native SVG availability, bounded state,
settings and component integration. They cannot prove KWin's animation, final
GPU visuals or real pointer crossing between surfaces. Those require CachyOS tests.

## Magnification anchor correction — 2026-11-14

Desktop feedback identified cross-axis drift in Custom mode on bottom and right
edges. The icon origin moves on those edges as it grows. Anchoring indicators
inside it made their animated position lag behind that moving origin. Top/left
origins stay fixed, explaining the edge-specific symptom.

Indicators now occupy a separate resting lane anchored to the capsule. Only the
longitudinal dimension follows magnification; the icon animation is unchanged.
Counter-rotated vertical items retain fractional centering to avoid rounding
jitter. Native strips and group symbols share this lane; macOS dots retain their
existing geometry. All configuration options remain available. Intentional
state-dependent indicator sizes still apply.

Frame-sampled tests reproduce the original bottom/right Custom failures and
verify stable cross-axis coordinates during growth and shrinkage on all four
edges, for Custom and native Plasma strips. Recheck this correction on CachyOS,
including configured state sizes, scrolling and adaptive fit.
