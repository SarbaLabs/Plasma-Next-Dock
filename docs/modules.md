# Dock module API 1

A package is a directory of editable files. The core discovers packages once at
process startup and creates an independent provider for each dock that enables
one. The initial release of the loader exposes entries and actions to the core
and a developer inspection command. Rendering lateral entries, their native
menus and the placement editor belong to subsequent roadmap PRs.

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

`enabledModules` is an ordered string list in a dock profile. Existing profiles
default to an empty list. Each provider receives only its own map from the
profile's `moduleSettings`, keyed by module ID, as `configuration` before QML
completion. Use bindings and defaults (the counter accepts a `label` string).
A host-side settings change updates the running provider. Treat this input as
read-only; changes made to the provider's copy do not persist. Optionally ship a
`Settings.qml` beside Main.qml. Discovery exposes its URL for the future settings
editor; it does not load a settings page at startup.

For a developer test before the editor is available, quit the dock, back up its
configuration, and run this command for a single module on the first dock:

```sh
kwriteconfig6 --file plasma-next-dock.ini --group General --key enabledModules org.example.counter
```

Restart the dock to load the enabled provider. Inspection works independently
of profile configuration.

## Errors and trust

Inspect diagnostics on standard error. Invalid manifests, unsupported API
versions and missing components are skipped. Enabled providers with QML load
errors or the wrong root type are skipped independently. Duplicate or incomplete
entries are ignored. Disabling a module destroys its per-dock instance.

Install third-party modules only from sources you trust. Their code runs in the
dock process with your user's privileges. The provider engine omits the dock's
private QML context; it is not a sandbox. If a broken module crashes the dock,
move its directory out of the search path and restart the dock.
