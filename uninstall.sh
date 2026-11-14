#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
set -euo pipefail
prefix="${PLASMA_NEXT_DOCK_PREFIX:-$HOME/.local}"
rm -f -- "$prefix/bin/plasma-next-dock" "$prefix/share/applications/org.sarbalabs.PlasmaNextDock.desktop"
for catalog in "$prefix"/share/locale/*/LC_MESSAGES/plasma-next-dock.mo; do
    rm -f -- "$catalog"
done
printf 'Removed Plasma Next Dock from %s. No Plasma configuration was changed.\n' "$prefix"
