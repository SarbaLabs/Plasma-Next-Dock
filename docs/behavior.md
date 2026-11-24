# Task behavior and pinned boundary

## Scope and native APIs

`BehaviorSettings.qml` exposes a separate settings draft. Apply persists only its
own keys; it cannot overwrite launcher changes made while the settings window is
open. English source strings use KI18n and the project French catalog.

`LiveTasks.qml` binds presentation settings to installed KDE TasksModel APIs:
GroupApplications/GroupDisabled, SortManual/Alpha/LastActivated/VirtualDesktop/
Activity, screenGeometry and desktop/activity/minimized filters. Its independent
collision model stays ungrouped and filtered to the current desktop and activity.
Displaying tasks from other desktops must not make those windows hide the dock.
The host supplies the selected output's global logical geometry, including negative
origins, and updates it on screen geometry changes.

Primary/middle/cycle actions use native requestActivate/requestToggleMinimized/
requestNewInstance/requestClose with fresh model indexes. `TaskBehavior.js` contains
the small action policy; it does not launch shell commands or duplicate a task
manager backend. Group cycling reads current child states on user input, wraps,
and optionally skips minimized windows. When all members are skipped it does
nothing. Direct activation leaves group activation semantics to KDE.

Native APIs inspected, without copying implementation:
- https://github.com/KDE/plasma-workspace/blob/master/libtaskmanager/tasksmodel.h
- https://github.com/KDE/plasma-workspace/blob/master/libtaskmanager/tasksmodel.cpp
- Installed Plasma 6.3 QML type metadata, with CachyOS 6.8 desktop validation pending.

## Settings and defaults

| Setting | Default | Choices |
| --- | --- | --- |
| Group applications | On | Application grouping or individual tasks |
| Group click | Previews | Previews, cycle, native activation |
| Sort | Manual | Manual, alphabetical, last activated, desktop, activity |
| Minimize active task on click | Off | Opt-in; preserves previous activation |
| Middle click | Nothing | Nothing, new instance, close, toggle minimization |
| Wheel | Overflow only | Overflow only or cycle hovered group's windows |
| Skip minimized when cycling | On | Applies to wheel and group-click cycling |
| Current desktop/activity filters | On | Independent display filters |
| Current screen / only minimized filters | Off | Independent display filters |
| Reveal on attention | Off | Inhibits hide while a visible model task requests attention |

Pinned launchers use the selected native sort order. KDE's manual row map is
rebuilt only after external launcher changes. The unpinned task provider controls
the trailing section, with its own per-dock sort preference. TaskRows maps visual
rows to the native model for actions, previews, drops and minimization targets.
Direction and separator preferences from older releases have no effect.

## Wheel and attention

Actual overflow always takes priority, preserving synthesized wheel, touchpad and
both-axis scrolling. Without overflow, optional cycling requires the pointer over
an icon. Each nonzero wheel event selects one window immediately, including pixel-only and
combined angle/pixel events. Angle direction takes precedence when supplied; there
is no distance accumulator for discrete window selection. At most one activation
is requested per event. Diagonal events are handled once.
No timer, animation-frame scan or background polling is introduced.

Attention uses TasksModel.anyTaskDemandsAttention as a separate optional controller
hide inhibitor, never as artificial pointer hover. Clearing attention restores the
usual overlap/hover/edge-availability policy. It does not activate a window, steal
focus or change global KWin behavior.

## Validation

Automated coverage includes native model grouping/filter/sort bindings, negative
output origin, sort binding after launcher updates, persistent settings and invalid
values, mock action dispatch and wrap/skip logic, independent module sorting and dynamic running-task pin changes, magnification cross-axis stability, existing adaptive overflow scrolling,
settings drafts and attention hide inhibition.

Offscreen rendering cannot establish live KWin behavior. On CachyOS validate:

- Every group-click and middle-click mode; active-task minimization.
- Wheel cycling with active/minimized siblings and all-minimized groups; then add
  enough apps for overflow and confirm the wheel scrolls the dock instead.
- Manual dragging within the pinned section, automatic sorting, saved launcher order
  after restart and changing settings while pinning an app.
- Desktop/activity/screen filters (including windows moving between outputs) and
  minimized-only filtering; confirm avoidance still concerns local visible windows.
- Trailing module placement on each edge; open/close/pin/unpin single and grouped
  apps; zoom near the boundary.
- Attention reveal/clear, inward tooltip/menu placement, media/audio badges,
  theme/blur/glow and hide/reveal regressions.

No installation changes or new dependencies. Use `./install.sh`, then restart only
Plasma Next Dock. Do not restart Plasma Shell or modify the existing plasmoid.
