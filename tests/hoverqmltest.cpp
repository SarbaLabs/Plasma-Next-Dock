// SPDX-License-Identifier: GPL-2.0-or-later
#include "controller.h"
#include "popupanchor.h"
#include "icons.h"
#include "settings.h"
#include <QtQuickTest/quicktest.h>
#include <QQmlContext>
#include <QQmlEngine>
#include <QIcon>
#include <QTemporaryDir>
#include <QFile>
#include <QUrl>
#include <QWheelEvent>
#include <QQuickItem>
class Setup : public QObject
{
    Q_OBJECT
    QTemporaryDir m_launchers;
    QQmlEngine *m_engine = nullptr;
public:
    Q_INVOKABLE void wheel(QQuickItem *item, QPointF position, QPoint delta, bool synthesized, bool pixels) {
        const QPointF scene = item->mapToScene(position);
        QWheelEvent event(scene, item->window()->mapToGlobal(scene), pixels ? delta : QPoint(),
                          pixels ? QPoint() : delta, Qt::NoButton, Qt::NoModifier,
                          Qt::NoScrollPhase, false, synthesized ? Qt::MouseEventSynthesizedBySystem : Qt::MouseEventNotSynthesized);
        QCoreApplication::sendEvent(item->window(), &event);
    }
    Q_INVOKABLE void setEdge(int edge) {
        auto options = m_engine->rootContext()->contextProperty("dockOptions").toMap();
        options["edge"] = edge;
        m_engine->rootContext()->setContextProperty("dockOptions", options);
    }
public Q_SLOTS:
    void qmlEngineAvailable(QQmlEngine *engine) {
        m_engine = engine;
        engine->rootContext()->setContextProperty("testEnvironment", this);
        initializeIconPaths();
        engine->rootContext()->setContextProperty("dockMenuAnchor", new PopupAnchor(engine));
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
