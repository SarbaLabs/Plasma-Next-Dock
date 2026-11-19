#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# KDE extraction convention; standard KDE strings use their installed catalogs.
"${XGETTEXT:-xgettext}" --package-name=plasma-next-dock --from-code=UTF-8 --language=JavaScript --keyword=i18n \
    qml/ApplicationChooser.qml qml/ContextMenu.qml qml/Settings.qml qml/BehaviorSettings.qml qml/IndicatorsSettings.qml qml/StatusOverlay.qml qml/MediaControls.qml -o "${podir:-po}/plasma-next-dock.pot"
"${XGETTEXT:-xgettext}" --join-existing --from-code=UTF-8 --language=C++ --keyword=i18n \
    src/dockprofiles.cpp -o "${podir:-po}/plasma-next-dock.pot"
