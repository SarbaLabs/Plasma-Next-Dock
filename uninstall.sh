#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
set -euo pipefail
prefix="${PLASMA_NEXT_DOCK_PREFIX:-$HOME/.local}"
template="$prefix/share/plasma-next-dock/org.sarbalabs.PlasmaNextDock.desktop"
entry="${XDG_CONFIG_HOME:-$HOME/.config}/autostart/org.sarbalabs.PlasmaNextDock.desktop"
if [[ -L "$entry" && "$(readlink -m -- "$entry")" == "$(realpath -m -- "$template")" ]]; then
    rm -- "$entry"
fi
rm -f -- "$template" "$prefix/bin/plasma-next-dock" "$prefix/share/applications/org.sarbalabs.PlasmaNextDock.desktop"
rm -f -- "$prefix/share/icons/hicolor/scalable/apps/org.sarbalabs.PlasmaNextDock.svg"
relay="$prefix/share/plasma/plasmoids/org.sarbalabs.nextdock.launcherrelay"
rm -f -- "$relay/metadata.json" "$relay/contents/ui/main.qml"
rmdir -- "$relay/contents/ui" "$relay/contents" "$relay" 2>/dev/null || true
module="$prefix/share/plasma-next-dock/modules/org.sarbalabs.unpinned"
rm -f -- "$module/metadata.json" "$module/Main.qml" "$module/Settings.qml"
rmdir -- "$module" 2>/dev/null || true
folder="$prefix/share/plasma-next-dock/modules/org.sarbalabs.folders"
rm -f -- "$folder/metadata.json" "$folder/Main.qml" "$folder/Settings.qml" "$folder/Folders.qml" "$folder/native/qmldir" "$folder/native/libfoldertools.so"
rmdir -- "$folder/native" "$folder" 2>/dev/null || true
trash="$prefix/share/plasma-next-dock/modules/org.sarbalabs.trash"
rm -f -- "$trash/metadata.json" "$trash/Main.qml" "$trash/native/qmldir" "$trash/native/libtrashtools.so"
rmdir -- "$trash/native" "$trash" 2>/dev/null || true
usb="$prefix/share/plasma-next-dock/modules/org.sarbalabs.usb"
rm -f -- "$usb/metadata.json" "$usb/Main.qml" "$usb/native/qmldir" "$usb/native/libusbtools.so"
rmdir -- "$usb/native" "$usb" 2>/dev/null || true
appmenu="$prefix/share/plasma-next-dock/modules/org.sarbalabs.appmenu"
rm -f -- "$appmenu"/{metadata.json,Main.qml,Settings.qml,Popup.qml,SessionBar.qml,native/qmldir,native/libmenutools.so}
rmdir -- "$appmenu/native" "$appmenu" 2>/dev/null || true
for catalog in "$prefix"/share/locale/*/LC_MESSAGES/plasma-next-dock.mo; do
    rm -f -- "$catalog"
done
printf 'Removed Plasma Next Dock from %s. Dock preferences were kept.\n' "$prefix"
