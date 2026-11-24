# Dock module API 1

A package is a directory of editable files. The core discovers packages once at
process startup and creates an independent provider for each dock that enables
one. Configure → Modules positions each provider as a block around the pinned launchers.
The inspection command also works for generic modules, such as the counter.

## Try the example

From the source checkout, with the new dock installed:

```sh
modules="${XDG_DATA_HOME:-$HOME/.local/share}/plasma-next-dock/modules"
mkdir -p "$modules"
cp -R examples/modules/org.example.counter "$modules/"
~/.local/bin/plasma-next-dock --list-modules
~/.local/bin/plasma-next-dock --inspect-module org.example.counter
```

Listing reads manifests only. Inspection runs the selected module with default
settings, prints its initial entries as JSON, and exits (nonzero on load failure).
Run again after editing its icon in Main.qml. To uninstall, move the package out
of the modules directory. Restart running docks after installing, replacing or
removing a package. Compatible updates require no core rebuild.

System packages use `plasma-next-dock/modules/<id>/` under an XDG data root
such as `/usr/share`. User data wins over system data, followed by the order in
`XDG_DATA_DIRS`. The first directory with a given ID claims it even if broken.
Removing an override restores the next copy on restart.

## Manifest and files

Use a stable lowercase ID with alphanumeric segments separated by dots or
hyphens. The directory name must match the manifest ID. Required files are
`metadata.json` and `Main.qml`. For example:

```json
{
  "id": "org.example.counter",
  "name": "Counter",
  "description": "A resettable counter",
  "version": "1.0",
  "apiVersion": 1,
  "nameTranslations": {"fr": "Compteur"},
  "descriptionTranslations": {"fr": "Un compteur réinitialisable"}
}
```

The version string belongs to the module author. The integer API version must
match a supported major exactly. For incompatible future contracts, publish the
new API version with the corresponding implementation. Default name and
description strings are required and act as localization fallbacks.

## Provider and entries

Import `org.sarbalabs.nextdock.modules 1.0` and use `DockModule` as the root
of Main.qml. See the [working counter](../examples/modules/org.example.counter/Main.qml).
Bind its `entries` list to the module's state. A change emits a notification.
When updating a JavaScript array imperatively, assign a new array to notify Qt.
Publish an empty list when temporarily unavailable. Use event notifications for
device, filesystem or service changes.

| Entry field | Meaning |
| --- | --- |
| id | Stable non-empty string, unique within this module |
| name, icon | Display name and KDE theme icon name (both required) |
| enabled | Optional boolean, defaults to true |
| actions | Optional list of menu descriptors |

The host adds the package ID as `moduleId`. The pair identifies an entry even
when a row moves. Handle a primary click with `onActivated: entryId => …`.
Each context action has a unique string `id`, a `text` label and optional
`enabled` flag. Use `children` for a submenu. Handle a selectable action with
`onActionTriggered: (entryId, actionId) => …`. The host resolves current IDs
and enabled states before dispatch. It owns native menus and their permanent
Configure and Quit actions. Providers supply data, never dock geometry.

## Per-dock configuration

`enabledModules` is an ordered string list in a dock profile. Existing profiles gain the official unpinned task module on upgrade. Other
modules remain opt-in. Each provider receives only its own map from the
profile's `moduleSettings`, keyed by module ID, as `configuration` before QML
completion. Use bindings and defaults (the counter accepts a `label` string).
A host-side settings change updates the running provider. Treat this input as
read-only; changes made to the provider's copy do not persist. Optionally ship a
`Settings.qml` beside Main.qml. Declare a Window or ApplicationWindow with a writable
`configuration` property and an `edited(var options)` signal. Pass only the preferences that changed.
The host merges top-level keys into the module’s current configuration for that
dock. A supplied list or nested object replaces the previous value of that key.
The host opens the window on demand from the context menu of a task contributed by the module.

To try the counter, restart after installing the example and drag it from
**Disabled** to either side in **Modules**. The gear opens a package’s settings
even if it is disabled or has no visible entries.

Each profile persists three ordered ID lists in `moduleZones` (left, disabled,
right). Both active columns are ordered from the outer edge toward the pins.
The host reverses the sequence of trailing blocks for display and keeps the
order of entries within each block. It derives `enabledModules` in physical
display order. Older profiles keep their previous display order on the trailing
side. New packages appear in Disabled. A missing package retains its placement
until reinstalled. Separators appear only at a boundary between visible pins
and a populated side. Placement and module preferences are separate per profile.

## Native task entries

The [unpinned applications package](../modules/org.sarbalabs.unpinned) uses
`TaskModule`, an API 1 specialization of `DockModule`. Its read-only
`candidates` list contains the current unpinned task identities, application
name, title, icon, last activation in milliseconds, desktop position and activity
label. Task IDs are opaque and valid for the lifetime of the native model item.
Publish a candidate ID as `taskRef` on an entry to reuse its existing native
task delegate, including group previews, menus, badges and action targeting.
Pinned membership and window avoidance are owned by the core. A task can occupy
only one visible slot. An empty or disabled provider contributes no slots.

The package's Settings.qml receives its per-profile `configuration` and emits
`edited(options)`. The context menu on a task contributed by the module opens the package’s own settings window. Its selector saves immediately.
The four orders are name, recent activation, virtual desktop and activity.
Old automatic sort preferences initialize the module; old manual order becomes
alphabetical. Moving the block preserves its sort preference.

## Errors and trust

Inspect diagnostics on standard error. Invalid manifests, unsupported API
versions and missing components are skipped. Enabled providers with QML load
errors or the wrong root type are skipped independently. Duplicate or incomplete
entries are ignored. Disabling a module destroys its per-dock instance.

Install third-party modules only from sources you trust. Their code runs in the
dock process with your user's privileges. The provider engine omits the dock's
private QML context; it is not a sandbox. If a broken module crashes the dock,
move its directory out of the search path and restart the dock.
