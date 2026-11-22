#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
# Report native dependencies before touching the build directory.
if [[ -r /etc/os-release ]]; then
    . /etc/os-release
elif [[ -r /usr/lib/os-release ]]; then
    . /usr/lib/os-release
fi
# Prefer the distribution's own identity, then its declared ancestry in order.
# An Ubuntu derivative may also list Debian, while an openSUSE system uses
# RPM just like Fedora but needs different package names and commands.
family=
read -ra lineage <<< "${ID:-} ${ID_LIKE:-}"
for ancestor in "${lineage[@]}"; do
    case "$ancestor" in
        debian|ubuntu) family=$ancestor ;;
        fedora|rhel|centos) family=fedora ;;
        opensuse*|suse|sles|sled) family=suse ;;
        arch|archlinux|cachyos) family=arch ;;
    esac
    if [[ -n "$family" ]]; then break; fi
done
packages=()
case "$family" in
    debian|ubuntu)
        mapfile -t packages < packaging/apt-common.txt
        installed() { [[ "$(dpkg-query -W -f='${db:Status-Status}' "$1" 2>/dev/null)" == installed ]]; }
        candidate() { LC_ALL=C apt-cache policy "$1" | awk '$1 == "Candidate:" && $2 != "(none)" {print $2}'; }
        # Qt moved the client development files into qtbase in 6.10.
        qt_version=$(candidate qt6-base-dev || true)
        if [[ -z "$qt_version" ]]; then
            qt_version=$(dpkg-query -W -f='${Version}' qt6-base-dev 2>/dev/null || true)
        fi
        # Without repository metadata, fall back to the family's tested layout.
        if [[ -n "$qt_version" ]]; then
            if dpkg --compare-versions "${qt_version#*:}" ge 6.10; then
                packages+=(qt6-base-dev-tools)
            else
                packages+=(qt6-wayland-dev qt6-wayland-dev-tools)
            fi
        elif [[ "$family" == ubuntu ]]; then
            packages+=(qt6-base-dev-tools)
        else
            packages+=(qt6-wayland-dev qt6-wayland-dev-tools)
        fi
        if installed kf6-breeze-icon-theme || [[ -n "$(candidate kf6-breeze-icon-theme)" ]]; then
            packages+=(kf6-breeze-icon-theme)
        elif installed breeze-icon-theme || [[ -n "$(candidate breeze-icon-theme)" || "$family" == debian ]]; then
            packages+=(breeze-icon-theme)
        else
            packages+=(kf6-breeze-icon-theme)
        fi
        available() { [[ -n "$(candidate "$1")" ]]; }
        install_command=(sudo apt install)
        ;;
    fedora|suse)
        installed() { rpm -q "$1" >/dev/null; }
        if [[ "$family" == suse ]]; then
            mapfile -t packages < packaging/opensuse-leap-16.1-packages.txt
            install_command=(sudo zypper install)
            available() {
                zypper --no-refresh --xmlout search --match-exact --type package "$1" |
                    grep -F "name=\"$1\"" >/dev/null
            }
        else
            mapfile -t packages < packaging/fedora-45-packages.txt
            install_command=(sudo dnf install)
            available() {
                dnf --cacheonly repoquery --available --queryformat '%{name}\n' "$1" |
                    grep -Fx "$1" >/dev/null
            }
            if [[ -e /run/ostree-booted ]]; then install_command=(rpm-ostree install); fi
        fi
        ;;
    arch)
        mapfile -t packages < packaging/arch-packages.txt
        install_command=(sudo pacman -S --needed)
        if (( EUID != 0 )) && command -v paru >/dev/null; then install_command=(paru -S --needed); fi
        available() { pacman -Si "$1" >/dev/null; }
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
        confirmed=()
        unverified=()
        for package in "${missing[@]}"; do
            if available "$package" 2>/dev/null; then confirmed+=("$package")
            else unverified+=("$package")
            fi
        done
        if (( ${#confirmed[@]} )); then
            printf '\nInstall the packages found in your repositories with:\n '
            printf ' %s' "${install_command[@]}" "${confirmed[@]}"
            printf '\n'
            if [[ ${install_command[0]} == rpm-ostree ]]; then
                printf 'Reboot into the updated deployment.\n'
            fi
        fi
        if (( ${#unverified[@]} )); then
            printf '\nPackage names unconfirmed in your repository metadata:\n'
            printf '  %s\n' "${unverified[@]}"
            printf 'Refresh your package metadata or check how your distribution provides these dependencies.\n'
        fi
        printf 'Then run ./install.sh again.\n'
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
