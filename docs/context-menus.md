# Native KDE context menus

## Implementation

`qml/ContextMenu.qml` is a small standalone controller around the actual
`org.kde.plasma.extras` Menu/MenuItem types used by KDE's task manager. Menus are
built on demand, remain alive while an action is being handled, and are replaced
on the next opening. Actions and submenus belong to that menu lifetime. The
controller belongs to the dock root rather than an animated/moving delegate.

The application now uses QApplication because PlasmaExtras constructs QMenu.
Qt Widgets and KDE's platform integration choose the application style and
palette. PlasmaExtras sets the alpha-capable native surface attributes required
by styles such as Breeze. The dock sets **no menu opacity, background, stylesheet,
blur strength or style override**. Plasma desktop theme SVGs are not a replacement
for this widget style. The older Plasma macOS Dock also used PlasmaExtras.Menu;
its opaque appearance alone does not identify an implementation difference.

`ApplicationMenuBackend` is the focused GPL-compatible backend imported from our
older fork (see licensing.md). It uses KService/KServiceAction for desktop actions,
KFilePlacesModel for the user's local/remote Places and their groups, KIO
ApplicationLauncherJob for launching, and PlasmaActivitiesStats for recent files.
Structured QUrls preserve spaces and remote URLs. Hidden Places are excluded.
The native More Places action reopens an expanded menu. No history database,
resource tracking service, command parser or global shortcut registration is added.

Recent files follow the current activity and application's agent ID. KDE history
privacy is reread both at construction and at activation. A no-history or blocked
application produces no recent section. Forget acts on that application's current
activity through KDE's existing API. A missing activity database produces no rows.

Window actions delegate to the existing native TasksModel: new instance, move,
resize, maximize, minimize, keep above/below, fullscreen, shade, close, desktops
and activities. Output movement is offered only when the installed TasksModel
exposes requestSendToOutput. Actual QScreen objects are passed. MPRIS controls are
provided when the matching player supports them. Pinning uses the unchanged
LiveTasks launcher APIs and persistence; background clicks expose Configure/Quit.

## Language

The old fork called generic i18n for several standard labels under a different
application catalog. Those calls cannot automatically find task-manager entries.
The new menu uses explicit `plasma_applet_org.kde.plasma.taskmanager` lookups with
the original contexts, including section headings. Headings fall back to the
context-free lookup used by Plasma 6.3 when the newer entry is unavailable. Application desktop actions and
Places retain their own KDE localization. Dock-specific strings use the
`plasma-next-dock` domain. French is included in po/fr; gettext/ki18n_install builds
and installs the catalog. Messages.sh extracts project strings. Other project
languages fall back to English until contributed; existing settings remain outside
this menu-only translation stage. No system language is hardcoded.

## Positioning and lifecycle

The click coordinate along the dock and visible capsule/icon envelope across it
produce a one-pixel visual parent. PlasmaExtras.openRelative places the native
menu inward using its actual size; the existing PopupAnchor supplies native
Wayland anchor/gravity. Qt Widgets creates the window before assigning its
transient parent, so the adapter handles that late assignment too. Submenus keep
their own parent positioning. The menu inhibits dodge while open. No canvas,
collision or magnification geometry is changed.

MenuTarget stores QPersistentModelIndex. Row removals/moves cannot redirect a
window action to a different task; disappearance invalidates and closes the menu.
Actions check validity at invocation. No per-frame scan, polling or timer is added.

## Dependencies and boundaries

New direct build dependencies: Qt Widgets, KF6 I18n (including I18nQml, >=6.8),
KIO FileWidgets, Service, Notifications, PlasmaActivitiesStats and gettext.
PlasmaExtras and MPRIS are installed Plasma runtime modules. On CachyOS the README
lists the package command; install.sh remains the complete build/test/install path.
The application remains standalone, with no installed plasmoid/native QML plugin.

This stage does not add task grouping, per-stream volume/mute integration, bounce,
window thumbnails or the old dock's blur/indicator systems. Those require their
own model/UI work. Native task operations and media control still need live KDE
Wayland validation; headless fixtures are not proof of compositor behavior.
