#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Exercise the installed package format through the same CLI used by authors.
set -eu
dock=$1
example=$2
temp=$(mktemp -d)
trap 'rm -rf -- "$temp"' EXIT
export XDG_DATA_HOME="$temp/user"
export XDG_DATA_DIRS="$temp/system"
export XDG_CONFIG_HOME="$temp/config"
export QT_QPA_PLATFORM=offscreen
id=org.example.counter
package="$XDG_DATA_HOME/plasma-next-dock/modules/$id"
mkdir -p "$package"
cp "$example/"{Main.qml,metadata.json} "$package/"
"$dock" --list-modules > "$temp/catalog"
grep -Fq "$id" "$temp/catalog"
"$dock" --inspect-module "$id" > "$temp/before"
grep -Fq 'accessories-calculator' "$temp/before"

# Only replace module source. The next process must load the new implementation.
sed 's/accessories-calculator/document-open/' "$example/Main.qml" > "$package/Main.qml"
"$dock" --inspect-module "$id" > "$temp/after"
grep -Fq 'document-open' "$temp/after"
mv "$package" "$temp/removed"
if "$dock" --inspect-module "$id"; then exit 1; fi
