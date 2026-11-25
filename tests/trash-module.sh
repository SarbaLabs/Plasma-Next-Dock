#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
set -eu
# KIO resolves the home trash by filesystem device. A tmpfs can be untrashable.
temp=$(mktemp -d "$HOME/.pnd-trash-test.XXXXXXXX")
trap 'rm -rf -- "$temp"' EXIT
export XDG_DATA_HOME="$temp/data" XDG_CONFIG_HOME="$temp/config" XDG_CACHE_HOME="$temp/cache"
export XDG_RUNTIME_DIR="$temp/run" QT_QPA_PLATFORM=offscreen
mkdir -m 700 "$XDG_RUNTIME_DIR" "$XDG_DATA_HOME" "$XDG_CONFIG_HOME"
# Move only the test item. The fixture never runs an empty-trash job.
printf '[KDE]\nConfirmTrash=false\n' > "$XDG_CONFIG_HOME/kiorc"
"$1" --config-file="$2" -- "$3"
