// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once
#include <QObject>
#include <QtQml/qqmlregistration.h>

// A no-QML-plugin module, matching the new applet packaging mechanism.
class StatusModuleProbe : public QObject
{
    Q_OBJECT
    QML_NAMED_ELEMENT(StatusModuleProbe)
public:
    using QObject::QObject;
};
class UnusedAppletFactory : public QObject
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID "org.sarbalabs.tests.UnusedAppletFactory")
public:
    UnusedAppletFactory() { qFatal("The applet factory must never be instantiated"); }
};
