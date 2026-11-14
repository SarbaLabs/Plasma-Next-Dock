// SPDX-License-Identifier: GPL-2.0-or-later
#include "statussupport.h"
#include <QQmlComponent>
#include <QQmlEngine>
#include <QTest>

class StatusSupportTest : public QObject
{
    Q_OBJECT
private Q_SLOTS:
    void loadsTypesWithoutInstantiatingApplet() {
        const auto paths = QCoreApplication::libraryPaths();
        QCoreApplication::setLibraryPaths({QStringLiteral(STATUS_FIXTURE_PATH)});
        StatusSupport support;
        QVERIFY2(support.prepareSmartLauncherModule(), qPrintable(support.smartLauncherLoadError()));
        QVERIFY(support.prepareSmartLauncherModule()); // Idempotent.
        QQmlEngine engine;
        QQmlComponent component(&engine);
        component.setData("import plasma.applet.org.kde.plasma.taskmanager\nStatusModuleProbe {}", QUrl());
        QVERIFY2(component.isReady(), qPrintable(component.errorString()));
        std::unique_ptr<QObject> object(component.create());
        QVERIFY(object);
        QCoreApplication::setLibraryPaths(paths);
    }
};
QTEST_GUILESS_MAIN(StatusSupportTest)
#include "statussupporttest.moc"
