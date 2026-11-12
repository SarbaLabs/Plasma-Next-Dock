// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once
#include <QIcon>
#include <QStandardPaths>
// Keep the platform-selected theme. Also support previews on platforms whose
// theme plugin only supplies the resource path (not the XDG icon directories).
inline void initializeIconPaths()
{
    auto paths = QIcon::themeSearchPaths();
    for (const auto &data : QStandardPaths::standardLocations(QStandardPaths::GenericDataLocation)) {
        const QString icons = data + QStringLiteral("/icons");
        if (!paths.contains(icons)) paths.append(icons);
    }
    QIcon::setThemeSearchPaths(paths);
    QIcon::setFallbackThemeName(QStringLiteral("breeze"));
}
