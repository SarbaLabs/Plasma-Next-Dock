#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
# This project never installs into plasmashell's plasmoid/plugin directories.
prefix="${PLASMA_NEXT_DOCK_PREFIX:-$HOME/.local}"
cmake -S . -B build -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_INSTALL_PREFIX="$prefix" -DBUILD_TESTING=ON
cmake --build build --parallel "$(nproc)"
ctest --test-dir build --output-on-failure
cmake --install build
printf '\nInstalled Plasma Next Dock to %s\n' "$prefix"
printf 'Start manually: %s/bin/plasma-next-dock --demo\n' "$prefix"
printf 'No autostart entry was created; the existing Plasma dock was not changed.\n'
