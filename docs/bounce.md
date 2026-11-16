# Icon bounce

## Behavior and defaults

Configure → Behavior → Icon bounce provides:

| Setting | Default | Range / purpose |
| --- | --- | --- |
| Enable icon bounce | On | Master switch, including manual test |
| Bounce on launch | On | Launcher clicks, new-instance requests and native IsStartup |
| Bounce on attention | On | Native IsDemandingAttention, including grouped tasks |
| Height | 0 (automatic) | 0–64 logical pixels; automatic uses 6–10 px based on icon size |
| Speed | 100% | 50–200%; scales the complete jump/rebound/pause sequence |
| Launch/test repetitions | 3 | 1–5 complete cycles |

The native application context menu adds Test Bounce Animation after Pin/Unpin.
It is disabled when the master switch is off and absent from the empty-background
menu. Its action resolves MenuTarget's persistent model index at trigger time;
reordering cannot leave it targeting a stale saved row. Native application actions,
Places, media controls, Pin/Unpin and Configure/Quit remain intact.

Attention repeats while KDE requests it and stops at rest when cleared. Launch and
manual feedback are finite even if application startup fails. Changing focus or
minimizing an existing window does not trigger launch feedback. Starting a bounce
never activates an application by itself.

## Geometry and lifecycle

TaskBounce.qml adapts the old dock's 220/200/110/100 ms jump/rebound phases and 280 ms
pause. The animation exposes a normalized positive offset; Main.qml maps it inward
on all four edges, in the rotated task strip's local coordinates. It adds to hover
lift without changing scale, falloff or longitudinal positions. The secondary
rebound is 30% of the main jump.

AdaptiveLayout reserves maximum bounce headroom in the drawing surface before
animation begins. Amplitude scales with adaptive icon shrinking. The visible
capsule, end padding, separator, indicators and dodge geometry do not bounce or
grow during animation. Native input geometry uses the same per-task lane as primary/middle clicks,
context targeting, drag hit testing and wheel cycling. Each lane spans the current
longitudinal icon bounds and the full inward bounce envelope through to the physical
screen edge. Bounce never moves this hit target or rebuilds its mask each frame.
Inter-task gaps and separators remain distinct; overflow clips to the canvas.
Badges and preview anchors continue to follow the actual icon.

Bounce stops at rest while dragging, while an interactive preview is displayed,
or while the controller requests native hiding. Attention resumes when suppression
ends if still requested; interrupted finite feedback is discarded. The edge
protocol does not expose actual compositor visibility, so hideRequested remains
policy intent, not an exact visibility notification. The separate revealAttention
setting controls whether an attention request brings the dock back.

Launch signals from LiveTasks and native context-menu new-instance actions are
retained by launcher URL and dispatched after menu/preview dismissal. Native startup role
changes cover externally initiated launches when KDE reports them. Repeated launch
notifications do not restart a running bounce. Synchronous row-count changes are coalesced before adaptive surface sizing, so a
launcher/window replacement cannot briefly shrink and regrow the canvas.
A bounded table (at most 64 service identities) lets a replacement startup/window
delegate recover the pending launch feedback rather than dropping a queued call to
a destroyed launcher. Entries expire after the configured finite sequence duration,
are pruned on launch and never trigger an unrelated row. A replacement starts its
own finite sequence; no timer or polling loop is introduced. Delegate destruction
still owns animation cleanup. Disabled/idle
components do not animate or update geometry.

## Provenance and installation

See licensing.md for the donor Task.qml and retained notices. No new dependency,
application version, release or system setting changes. Install the complete
executable/QML resources with `./install.sh`, then restart only Plasma Next Dock.

## Desktop acceptance

Automated tests exercise animation lifecycle, finite completion, attention clear,
master/launch disabling, startup, suppression, inward motion on all four edges,
large amplitude with simultaneous zoom/lift, fixed indicators/capsule, small-output
headroom, settings persistence and native test-menu dispatch.

Validate on CachyOS/KWin:

- Test Bounce Animation on pinned, running and grouped applications; no launching
  or focus changes from the test action, correct target after reorder.
- Launch pinned applications and request a new instance from middle/context clicks;
  compare launch toggle on/off. Native external startup depends on application support.
- Trigger/clear application attention, with revealAttention both on and off.
- Test four edges, reverse order, HiDPI, crowded dock shrink/scroll, high zoom/lift,
  0/64 px height, 50/200% speed and master disable mid-animation.
- Hover, preview open/close, drag, native menu placement, audio/badges, separator,
  blur/glow and hide/reveal remain usable and correctly aligned.

Offscreen software rendering cannot validate compositor visibility, live startup
notifications or the feel of the animation under Wayland.

## Interaction correction — 2026-11-16

Maintainer video exposed lost clicks below moving icons and hover/zoom flicker
when an icon bounced away from the cursor. The original TapHandlers and Wayland
mask both followed the icon. Stable edge lanes now decouple interaction from that
visual animation. Launch feedback also survives synchronous model replacement.

Recheck primary/middle clicks with the pointer held against the physical edge,
between the icon and capsule, and on the icon itself. Launch a closed application,
then another instance, without moving the pointer. Zoom should remain active;
leaving the complete task/capsule/edge input region should still reset it. Repeat
on all four edges with reversed order and overflow; verify audio mute controls
still take priority and tooltips remain anchored to the visible icon.

### Remaining zoom correction

The maintainer confirmed the edge lane but reported a remaining zoom dip when the
animated icon's outward edge crossed the cursor, and once on initial launch.
DockController now observes Enter/Leave and mouse position events on the dock
window before Qt Quick routes them through moving child items. Hover is tested
against the existing input region; duplicate positions and child hover changes
do not recalculate the logical pointer index. Real departure still resets zoom.
The observer consumes no events, uses no polling/global cursor query, and is
detached when its target/window changes. Glow uses the same position but remains
clipped and enabled only inside the visible capsule.

New task delegates initialize their zoom factor before enabling its transition.
Replacing a launcher thus starts at the current hover size instead of animating
from a construction-time zero. Existing click lanes and animation settings remain
unchanged. Automated checks now place a stationary cursor just inside the icon's
outward edge, run a middle-click bounce past it on all four edges, assert a stable
logical pointer and retained zoom, then verify a true exit restores resting size.

### First-window row identity

Window-level pointer tracking and the edge lane were accepted by the maintainer.
A remaining first-window dip prompted a model-transition regression test: moving
an application from row 0 to row 1 reduced its icon from 60 to 46.8 px with the
cursor stationary. A subsequent replacement at a different row also initialized
at the old numeric hover distance (49.2 px instead of 60 px).

Main now retains the hovered delegate, launcher service key and fractional hover
position. Model index changes remap the logical anchor to that application;
replacement delegates recover it by service key and initialize their zoom directly
before painting. Real pointer movement chooses a fresh anchor normally. No timer,
new setting, input-region change or alteration to bounce phases is introduced.
The regression test also checks that moving to another icon releases the anchor.
