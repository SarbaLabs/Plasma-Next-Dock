// SPDX-License-Identifier: GPL-2.0-or-later
#include "controller.h"
#include "icons.h"
#include "settings.h"
#include <QtQuickTest/quicktest.h>
#include <QQmlContext>
#include <QQmlEngine>
#include <QIcon>
#include <QTemporaryDir>
#include <QFile>
#include <QUrl>
class Setup : public QObject
{
    Q_OBJECT
    QTemporaryDir m_launchers;
public Q_SLOTS:
    void qmlEngineAvailable(QQmlEngine *engine) {
        initializeIconPaths();
        QStringList urls;
        for (const auto &name : {"First", "Second"}) {
            const auto path = m_launchers.filePath(QString::fromLatin1(name) + ".desktop");
            QFile file(path); file.open(QIODevice::WriteOnly);
            file.write((QString("[Desktop Entry]\nType=Application\nName=%1\nExec=/bin/true\nIcon=folder\n").arg(name)).toUtf8());
            file.close(); urls << QUrl::fromLocalFile(path).toString();
        }
        engine->rootContext()->setContextProperty("testLauncherUrls", urls);
        engine->rootContext()->setContextProperty("dockSettings", new DockSettings("/unused", false, engine));
        engine->rootContext()->setContextProperty("outputNames", QStringList{QString(), "DP-1"});
        engine->rootContext()->setContextProperty("dockController", new DockController(nullptr, engine));
        engine->rootContext()->setContextProperty("outputSize", QSize(1000, 700));
        engine->rootContext()->setContextProperty("dockOptions", QVariantMap{
            {"demo", true}, {"edge", 0}, {"iconSize", 40}, {"zoom", 1.5}, {"radius", 10}, {"glow", true}, {"launchers", QStringList{}}});
    }
};
QUICK_TEST_MAIN_WITH_SETUP(hover, Setup)
#include "hoverqmltest.moc"
