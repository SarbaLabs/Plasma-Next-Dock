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
grow during animation. Native input geometry follows the moved icons via the
existing geometry update path; badges and preview anchors follow the actual icon.

Bounce stops at rest while dragging, while an interactive preview is displayed,
or while the controller requests native hiding. Attention resumes when suppression
ends if still requested; interrupted finite feedback is discarded. The edge
protocol does not expose actual compositor visibility, so hideRequested remains
policy intent, not an exact visibility notification. The separate revealAttention
setting controls whether an attention request brings the dock back.

Launch signals from LiveTasks and native context-menu new-instance actions are
queued to the current delegate, after menu/preview dismissal. Native startup role
changes cover externally initiated launches when KDE reports them. Repeated launch
notifications do not restart a running bounce. Delegate destruction owns animation
cleanup; no global task cache, timer or polling loop is introduced. Disabled/idle
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
