# Capsule backgrounds and native blur

## Modes and saved settings

| Key | Default | Meaning |
| --- | --- | --- |
| backgroundType | 0 | 0 Solid, 1 Transparent, 2 Translucent, 3 System Blur, 4 Liquid Glass |
| backgroundOpacity | 0.35 | Tint opacity, 0–1, for modes 2–4 |
| radius | 10 | **Existing setting**, pixels, 0–96; clamped to half the smaller capsule dimension |
| borderWidth | 1 | Border thickness, 0–12 logical pixels; 0 removes the border |
| borderUseTheme | true | Use the theme's disabled-text color for the border |
| borderColor | #808080 | Saved custom color, used when borderUseTheme is false |
| iconSpacing | 10 | Gap between neighboring icons, 0–64 |
| horizontalPadding | 12 | Padding at both ends along the dock, 0–128 |
| verticalPadding | 10 | Padding on both sides across dock thickness, 0–64 |
| glow | false | Existing bounded hover glow; suppressed in Transparent mode |

All are stored in the existing plasma-next-dock.ini, using Apply/Close semantics.
Mode switches retain the other values. Unknown modes fall back to Solid; numeric
values are bounded and non-finite values use defaults. No second radius control
or migration is introduced. Solid preserves the existing theme background/border.
Transparent removes all capsule paint and blur, but keeps the same input/dodge
geometry and icons. Translucent paints tint only. System Blur adds KWin blur
behind tint. Liquid Glass adds theme-aware glass tint and internal gloss.
The existing glow follows both pointer axes and shares the rounded path; border
and gloss paint above it. Transparent does not allocate a glow or extract colors
for it (icon-colored indicators may independently need extraction).

## Spacing and padding

The three layout values are independent. End padding follows the long axis;
thickness padding follows the short axis, so a side dock uses vertical end padding
and horizontal thickness padding. Existing distance-from-screen-edge spacing is
unchanged and separate. Defaults reproduce the previous 10/12/10 geometry.
For short task lists, the capsule now follows content plus the requested end
padding rather than imposing the former 160-pixel minimum capsule length.

AdaptiveLayout includes all three values in its resting/zoom budget. They scale
down with icons when the output is crowded, without changing their saved values.
The cross-axis drawing canvas includes both padding sides plus magnification
headroom. Scroll limits include end padding. No animated geometry feeds back
into the preferred size. Border thickness and radius remain logical pixels.

## Geometry and ownership

The visible capsule alone defines blur, never the larger icon canvas or edge
input corridor. Geometry stays in logical window coordinates; KWindowSystem
handles Wayland. QRegion rasterization quantizes vector edges to logical pixels.
A zero radius gives square corners; large radii clamp consistently in QML/C++.
An empty/clipped-out region disables effects, because an empty enabled KWin region
would otherwise mean the entire window. Radius changes propagate immediately even
if width and height stay unchanged.

BackgroundEffects belongs to DockHost and uses KWindowEffects for blur. It has no native QML plugin import, no shader capture and no render-thread
callbacks. Coalesced queued GUI-thread work applies only changed geometry
or explicit lifecycle restoration. It commits surface updates while stationary.
Temporary hidden/unexposed windows retain pending state; surface teardown clears
requests while the native surface is valid. QPointer and context-bound queued
callbacks protect destruction. Recreated hosts receive current settings.

The former plasmoid shared a PanelView which could clear its effects on mask,
floating-state and wallpaper-derived theme changes. This standalone surface has
one effect owner. Therefore no panel-property polling or Plasma theme ordering
workaround is needed. Palette changes still trigger a bounded restoration pass;
KWindowSystem also watches exposure and Wayland effect-manager availability.
Restoration clears/reapplies the blur request to bypass stale Frameworks caches.

Sources consulted (API use, no compositor code copied):
- [KWindowSystem Wayland effects](https://github.com/KDE/kwindowsystem/blob/master/src/platforms/wayland/windoweffects.cpp)
- [Prior dock blur investigation](https://github.com/SarbaLabs/plasma-macos-dock/blob/master/docs/blur-restoration.md)

## Limits

KWin's blur effect must be available and enabled by the user. This application
does not enable effects or alter global settings. Without compositor support,
the tint/gloss still renders but the background is not blurred. The ineffective saturation, contrast and brightness controls were removed after
desktop feedback. Their old INI keys are ignored; native contrast registration is
no longer requested. Compositor effects retain control of their own appearance. Blur strength remains
KWin's setting, not an ineffective local slider. Liquid Glass is tint/gloss plus
blur, not desktop refraction. No blur is claimed on other compositors.

Native hide/reveal remains owned by KWin's Sliding Popups and screen-edge protocols.
No client-side animation competes with it. Actual blur during compositor animations,
wallpaper blending, fractional scaling and Better Blur DX needs desktop testing.

## Manual acceptance on CachyOS

Update the feature branch and use the existing installer:

```bash
cd ~/git/Plasma-Next-Dock
git fetch origin
git switch --track origin/feature/capsule-backgrounds
./install.sh
```

If the local branch already exists, switch to it and run git pull --ff-only before
./install.sh. Quit and restart only Plasma Next Dock to load the new executable.
Do not restart Plasma Shell or install the old plasmoid's native plugin.

1. Existing installation: Solid, saved radius, indicator modes and glow stay as
   configured. Open settings, cancel changes, apply changes, restart and check
   persistence. Confirm there is exactly one radius setting.
2. Cycle all five backgrounds. Check no residual blur in Solid/Transparent/
   Translucent, theme colors, tint opacity, contour width/color, and theme/custom border switching.
3. In System Blur and Liquid Glass, use radius 0, 5, 10, 20 and a value above half
   the capsule thickness. Check corners, border, gloss and glow on all four edges,
   including small adaptive icons, magnification, scrolling and fractional scale.
4. Hide/recall at least 20 times, with pointer outside the capsule where possible;
   move/minimize overlapping windows using the keyboard. Test rapid animation
   reversals and a window touching only the capsule.
5. With wallpaper-derived accent colors enabled, use Next Wallpaper Image with
   distinct colors repeatedly while visible, hidden and during recall. Verify blur
   without hovering, and repeat ordinary theme/color-scheme changes.
6. Test native KWin blur, then Better Blur DX separately if installed. Disable the
   effect temporarily to check the tint-only fallback, then enable it again.
7. Change screen/edge, including different output origins/scales. Check native
   menus, previews, drag reorder, pinning, indicator alignment and smooth zoom.

Headless checks cover logic, QML composition and effect requests, not compositor
pixels or live Wayland event ordering. Record Qt/KF/Plasma versions and the effect
used for any failure; do not conceal failures with periodic refresh timers.

## Desktop refinement — 2026-11-15

The maintainer accepted the backgrounds but reported no visible effect from the
three contrast-related controls. These controls and requests are removed rather
than promising effects the tested compositor does not provide. Tint opacity remains.
Check border 0/1/3 px, custom/theme colors, and independent 0/default/large spacing
and padding on all four edges. Repeat adaptive shrink/recovery and overflow scroll,
magnification, indicator alignment, glow clipping, previews and dodge.

## Hover controls

Position and appearance now exposes Blast radius (neighbor icons), 0–8, and
Hover lift (px), 0–64. Defaults are 2 and 0, preserving the previous appearance.
Try radius 2 and lift 6 for the requested example. Lift points into the desktop
on every edge, scales down with adaptive icons, and leaves the capsule/indicators
stationary across its thickness. Larger radii reserve more length for neighboring
zoom, so a crowded dock may shrink sooner. Check 100% magnification with lift,
zero radius/lift, large radii, four edges, scrolling, previews and rapid pointer
movement. These remain desktop acceptance items.
