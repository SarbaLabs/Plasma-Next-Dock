#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
# Resolve distribution package names before CMake probes the installed Qt/KDE APIs.
if [[ -r /etc/os-release ]]; then
    . /etc/os-release
    elevate=()
    if (( EUID != 0 )); then elevate=(sudo); fi
    case "${ID:-}-${VERSION_ID:-}" in
        debian-13|ubuntu-26.04) manifest="packaging/$ID-$VERSION_ID-packages.txt" ;;
        *) manifest="" ;;
    esac
    if [[ -n "$manifest" ]]; then
        mapfile -t packages < packaging/apt-common.txt
        mapfile -t -O "${#packages[@]}" packages < "$manifest"
        missing=()
        for package in "${packages[@]}"; do
            if [[ "$(dpkg-query -W -f='${db:Status-Status}' "$package" 2>/dev/null || true)" != installed ]]; then
                missing+=("$package")
            fi
        done
        if (( ${#missing[@]} )); then
            "${elevate[@]}" apt-get update
            "${elevate[@]}" apt-get install -y --no-remove --no-install-recommends "${missing[@]}"
        fi
    elif [[ "${ID:-}-${VERSION_ID:-}" == fedora-45 || "${ID:-}-${VERSION_ID:-}" == opensuse-leap-16.1 ]]; then
        mapfile -t packages < "packaging/$ID-$VERSION_ID-packages.txt"
        if ! rpm -q "${packages[@]}" >/dev/null; then
            if [[ "$ID" == opensuse-leap ]]; then
                "${elevate[@]}" zypper --non-interactive install --no-recommends "${packages[@]}"
            else
                "${elevate[@]}" dnf install -y "${packages[@]}"
            fi
        fi
    fi
fi
# This project never installs into plasmashell's plasmoid/plugin directories.
prefix="${PLASMA_NEXT_DOCK_PREFIX:-$HOME/.local}"
cmake -S . -B build -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_INSTALL_PREFIX="$prefix" -DBUILD_TESTING=ON
cmake --build build --parallel "${CMAKE_BUILD_PARALLEL_LEVEL:-$(nproc)}"
ctest --test-dir build --output-on-failure
cmake --install build
printf '\nInstalled Plasma Next Dock to %s\n' "$prefix"
printf 'Start manually: %s/bin/plasma-next-dock --demo\n' "$prefix"
printf 'No autostart entry was created; the existing Plasma dock was not changed.\n'
