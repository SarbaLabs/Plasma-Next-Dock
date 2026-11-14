# Application status

Branch: `feature/application-status`, based on accepted PR #7.

## Composition and KDE integration

`TaskStatus.qml` binds one task identity to three independent installed KDE APIs:

- `AudioService.qml`: plasma-pa SinkInputModel filtered to non-virtual streams.
  Match portal application ID first, then task/group child PID (including a parent
  PID fallback), then application name when no prior PID match makes it ambiguous.
  StatusSupport reads a single /proc stat on demand, without a taskmanager Backend.
- Mpris2Model: playerForLauncherUrl plus PID, never the global active player.
  MediaControls exposes only capabilities advertised by that matched player.
- SmartLauncherItem: native KDE counters and job/Unity progress, notification
  privacy/DND/blacklist handling. Load the modern applet module first and the older
  private.taskmanager module as a compatibility fallback. Only this status type is
  instantiated: no shortcut-registering Backend or duplicate task model.

The dock uses KDE private QML APIs already shipped in Plasma; compatibility must
be checked after Plasma upgrades. No component implementation or theme is bundled
except the attributed audio-model adapter. Missing status modules cannot replace
or alter the native menus, indicators, geometry or effect owner.

Model notifications coalesce refreshes with Qt.callLater. There is one audio model
and one status MPRIS model for the dock, no timer and no frame-driven matching.
The audio model unloads when both audio display and preview media controls are off.
SmartLauncher objects exist only while counters or progress are enabled and are
replaced on launcher identity changes. Thumbnail capture remains visible-card-only.

StatusOverlay sits on the upright icon, independently of the resting running-state
indicator lane. Count badges are capped visually at 999+, not confused with group
counts. Progress is a separate strip. The speaker button consumes its click and
the task tap handler is disabled while it is hovered. Muting snapshots the group
state before modifying streams; volume changes retain their relative levels and
never exceed normal volume. No global output/device volume is modified.

TaskPreview retains the native Plasma tooltip and inward positioning. It adds
media/volume controls below the window list. Turning hover previews off hides the
cards and prevents their capture, while title/media remain available. Explicit
click on a grouped task still requests the selector.

## Configuration

All of these booleans default to true, persist through restart, and are independent:
`showWindowPreviews`, `showAudioIndicator`, `muteOnClick`, `showMediaControls`,
`showBadges`, `showProgress`. Existing saved settings use these defaults. Settings
and accessible control names use KI18n, with French translations in the project
catalog. Features depend on application support; an absent stream/player/counter
produces no empty control. No separate notification/history database is maintained.

## Validation

Local Qt 6.8.2 / Plasma 6.3 compatibility checks use installed native KDE modules.
The regular 13 CTest entries pass offscreen, including status control/overlay tests,
settings persistence/UI, menus, all edges, rendering and live TasksModel imports.
Native AudioService and SmartLauncherItem load successfully in the isolated runner.
The additional native-application-status test uses dbus-run-session and a temporary
application/notification environment to send a real Unity launcher signal into
KDE SmartLauncherItem. Local sockets are forbidden here, so its D-Bus round trip
cannot run locally; CI must verify it. This is not live CachyOS acceptance.

Desktop acceptance on CachyOS / KWin Wayland:

1. Play Firefox/Spotify or another MPRIS-capable application. Check the speaker,
   mute/unmute (without activation), track metadata and supported playback buttons.
2. Adjust application volume, including multiple streams; unrelated apps and the
   system output volume must be unaffected. Close/reopen the application and change
   streams while the preview is open. Check grouped and sandboxed applications.
3. Check actual supported download/copy progress and counters. Verify KDE's badge
   restrictions/DND and independent dock toggles; no unsupported app is promised.
4. Disable hover previews: title/media remain, group click still selects windows.
   Switch tooltip owners repeatedly, including apps without media, and ensure the
   previous application's controls and streams do not remain selected.
5. Check four edges, multiple outputs/scales, zoom/lift, scrolling, native menus,
   input corridor, hiding/reveal, glow and both blur modes. Check that popup controls
   do not close prematurely and remain inside the available display.
6. Apply/reopen settings, restart only the dock and verify all six values persist.

The next planned branch covers behavior settings and the pinned/unpinned separator.
Bounce follows later. Preview-triggered hiding of other windows requires separate
investigation and is not implemented or represented as a working toggle here.

### CachyOS installation follow-up

See [testing.md](testing.md#cachyos-resource-loading-follow-up) for the Qt 6.12
missing-resource report, isolated test resource bundle and tooltip lifetime fix.
Failed tests stop installation; new audio controls cannot be assessed using the
previous installed executable. Actual Qt 6.12/Plasma 6.8 acceptance remains pending.
