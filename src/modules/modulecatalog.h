// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once
#include <QMap>
#include <QUrl>
#include <QVariantMap>

struct ModulePackage
{
    QVariantMap metadata;
    QUrl entryPoint;
};

// Discovery reads metadata only. A catalog can be shared by all dock profiles.
using ModuleCatalog = QMap<QString, ModulePackage>;
ModuleCatalog discoverModules(const QStringList &dataRoots);
