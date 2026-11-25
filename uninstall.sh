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
module="$prefix/share/plasma-next-dock/modules/org.sarbalabs.unpinned"
rm -f -- "$module/metadata.json" "$module/Main.qml" "$module/Settings.qml"
rmdir -- "$module" 2>/dev/null || true
folder="$prefix/share/plasma-next-dock/modules/org.sarbalabs.folders"
rm -f -- "$folder/metadata.json" "$folder/Main.qml" "$folder/Settings.qml" "$folder/Folders.qml" "$folder/native/qmldir" "$folder/native/libfoldertools.so"
rmdir -- "$folder/native" "$folder" 2>/dev/null || true
trash="$prefix/share/plasma-next-dock/modules/org.sarbalabs.trash"
rm -f -- "$trash/metadata.json" "$trash/Main.qml" "$trash/native/qmldir" "$trash/native/libtrashtools.so"
rmdir -- "$trash/native" "$trash" 2>/dev/null || true
for catalog in "$prefix"/share/locale/*/LC_MESSAGES/plasma-next-dock.mo; do
    rm -f -- "$catalog"
done
printf 'Removed Plasma Next Dock from %s. No Plasma configuration was changed.\n' "$prefix"
