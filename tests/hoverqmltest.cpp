// SPDX-License-Identifier: GPL-2.0-or-later
#include "controller.h"
#include "icons.h"
#include <QtQuickTest/quicktest.h>
#include <QQmlContext>
#include <QQmlEngine>
#include <QIcon>
class Setup : public QObject
{
    Q_OBJECT
public Q_SLOTS:
    void qmlEngineAvailable(QQmlEngine *engine) {
        initializeIconPaths();
        engine->rootContext()->setContextProperty("dockController", new DockController(nullptr, engine));
        engine->rootContext()->setContextProperty("outputSize", QSize(1000, 700));
        engine->rootContext()->setContextProperty("dockOptions", QVariantMap{
            {"demo", true}, {"edge", 0}, {"iconSize", 40}, {"zoom", 1.5}, {"radius", 10}, {"glow", true}});
    }
};
QUICK_TEST_MAIN_WITH_SETUP(hover, Setup)
#include "hoverqmltest.moc"
