#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
# Report native dependencies before touching the build directory.
if [[ -r /etc/os-release ]]; then
    . /etc/os-release
fi
packages=()
case "${ID:-}-${VERSION_ID:-}" in
    debian-13|ubuntu-26.04|ubuntu-26.10)
        manifest="packaging/ubuntu-26.04-packages.txt"
        if [[ "$ID" == debian ]]; then manifest="packaging/debian-13-packages.txt"; fi
        mapfile -t packages < packaging/apt-common.txt
        mapfile -t -O "${#packages[@]}" packages < "$manifest"
        install_command=(sudo apt install)
        installed() { [[ "$(dpkg-query -W -f='${db:Status-Status}' "$1" 2>/dev/null)" == installed ]]; }
        ;;
    fedora-45|opensuse-leap-16.1)
        mapfile -t packages < "packaging/$ID-$VERSION_ID-packages.txt"
        install_command=(sudo dnf install)
        if [[ "$ID" == opensuse-leap ]]; then install_command=(sudo zypper install); fi
        installed() { rpm -q "$1" >/dev/null; }
        ;;
    cachyos-*|arch-*)
        mapfile -t packages < packaging/arch-packages.txt
        install_command=(sudo pacman -S --needed)
        installed() { pacman -T "$1" >/dev/null; }
        ;;
esac
missing=()
for package in "${packages[@]}"; do
    if ! installed "$package"; then missing+=("$package"); fi
done
if (( ${#missing[@]} )); then
    {
        printf 'Missing dependencies for %s:\n' "${PRETTY_NAME:-$ID}"
        printf '  %s\n' "${missing[@]}"
        printf '\nInstall them with:\n  '
        printf '%s ' "${install_command[@]}" "${missing[@]}"
        printf '\nThen run ./install.sh again.\n'
    } >&2
    exit 1
fi
# This project never installs into plasmashell's plasmoid/plugin directories.
prefix="${PLASMA_NEXT_DOCK_PREFIX:-$HOME/.local}"
if ! cmake -S . -B build -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_INSTALL_PREFIX="$prefix" -DBUILD_TESTING=ON; then
    if (( ${#packages[@]} == 0 )); then
        printf 'No package list for %s. See README.md (Build and install) and the CMake diagnostic above. Install the required development packages and rerun ./install.sh.\n' "${PRETTY_NAME:-this system}" >&2
    fi
    exit 1
fi
cmake --build build --parallel "${CMAKE_BUILD_PARALLEL_LEVEL:-$(nproc)}"
ctest --test-dir build --output-on-failure
cmake --install build
printf '\nInstalled Plasma Next Dock to %s\n' "$prefix"
printf 'Start manually: %s/bin/plasma-next-dock --demo\n' "$prefix"
printf 'No autostart entry was created; the existing Plasma dock was not changed.\n'
