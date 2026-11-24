// SPDX-License-Identifier: GPL-2.0-or-later
#include "modules/modulemanager.h"
#include "settings.h"
#include "modules/taskrows.h"
#include <QStandardItemModel>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QTest>

class ModuleManagerTest : public QObject
{
    Q_OBJECT
    QTemporaryDir dir;
    const QString id = "org.example.counter";

    QString package(const QString &root, const QString &name) const
    {
        return dir.filePath(root + "/plasma-next-dock/modules/" + name);
    }
    void write(const QString &path, const QByteArray &bytes)
    {
        QFile f(path);
        QVERIFY(f.open(QIODevice::WriteOnly));
        QCOMPARE(f.write(bytes), bytes.size());
    }
    void install(const QString &root, const QString &name, int api = 1)
    {
        const QString target = package(root, name);
        QVERIFY(QDir().mkpath(target));
        QFile source(QStringLiteral(MODULE_EXAMPLE) + "/Main.qml");
        QVERIFY(source.open(QIODevice::ReadOnly));
        write(target + "/Main.qml", source.readAll());
        write(target + "/metadata.json", QJsonDocument::fromVariant(QVariantMap{
            {"id", name}, {"name", name}, {"description", "test"}, {"version", root}, {"apiVersion", api}
        }).toJson());
    }
private Q_SLOTS:
    void overridesAndRemoval()
    {
        install("system", id);
        install("user", id);
        const QStringList roots{dir.filePath("user"), dir.filePath("system")};
        QCOMPARE(discoverModules(roots).value(id).metadata.value("version"), "user");
        install("user", id, 42);
        QVERIFY(!discoverModules(roots).contains(id));
        QVERIFY(QDir(package("user", id)).removeRecursively());
        QCOMPARE(discoverModules(roots).value(id).metadata.value("version"), "system");
    }

    void errorsAreLocalToTheirPackage()
    {
        for (const auto &name : {id, QString("syntax"), QString("wrong-root"), QString("missing"), QString("invalid")})
            install("errors", name);
        write(package("errors", "invalid") + "/metadata.json", "{");
        QVERIFY(QFile::remove(package("errors", "missing") + "/Main.qml"));
        write(package("errors", "syntax") + "/Main.qml", "{");
        write(package("errors", "wrong-root") + "/Main.qml", "import QtQml\nQtObject {}");
        const auto catalog = discoverModules({dir.filePath("errors")});
        QCOMPARE(catalog.size(), 3);
        ModuleManager manager(catalog);
        manager.configure({id, "syntax", "wrong-root", "missing"}, {});
        QVERIFY(manager.loaded(id));
        QVERIFY(!manager.loaded("syntax"));
        QVERIFY(!manager.loaded("wrong-root"));
        QCOMPARE(manager.entries().size(), 1);
    }

    void perDockLifecycleAndActions()
    {
        install("actions", id);
        const auto catalog = discoverModules({dir.filePath("actions")});
        ModuleManager first(catalog), second(catalog);
        QSignalSpy changes(&first, &ModuleManager::entriesChanged);
        first.configure({}, {});
        QCOMPARE(changes.count(), 0);
        first.configure({id, id}, {{id, QVariantMap{{"label", "Local"}}}});
        QVERIFY(first.loaded(id));
        QCOMPARE(first.entries().size(), 1);
        QCOMPARE(first.entries().first().toMap().value("name"), "Local (0)");
        QVERIFY(!first.trigger(id, "counter", "reset"));
        QVERIFY(first.activate(id, "counter"));
        QCOMPARE(first.entries().first().toMap().value("name"), "Local (1)");
        second.configure({id}, {});
        QCOMPARE(second.entries().first().toMap().value("name"), "Counter (0)");
        first.configure({id}, {});
        QCOMPARE(first.entries().first().toMap().value("name"), "Counter (1)");
        QVERIFY(first.trigger(id, "counter", "reset"));
        QCOMPARE(first.entries().first().toMap().value("name"), "Counter (0)");
        first.configure({}, {});
        QVERIFY(first.entries().isEmpty());
        QVERIFY(!first.activate(id, "counter"));
        QVERIFY(second.loaded(id));
    }

    void unpinnedTaskSection()
    {
        const QString module = "org.sarbalabs.unpinned";
        const QDir packageDir(QStringLiteral(UNPINNED_PACKAGE));
        ModuleCatalog catalog{{module, {{}, QUrl::fromLocalFile(packageDir.filePath("Main.qml"))}}};
        ModuleManager manager(catalog);
        QStandardItemModel source;
        enum { Pinned = Qt::UserRole + 1, Desktop, Activity, Activated };
        source.setItemRoleNames({{Qt::DisplayRole, "display"}, {Pinned, "HasLauncher"},
            {Desktop, "VirtualDesktops"}, {Activity, "Activities"}, {Activated, "LastActivated"}});
        for (const auto &name : {"Zulu", "Pinned", "Alpha"}) source.appendRow(new QStandardItem(name));
        source.item(1)->setData(true, Pinned);
        source.item(0)->setData(QDateTime::fromMSecsSinceEpoch(10000), Activated);
        source.item(0)->setData(QVariantList{"second"}, Desktop);
        source.item(2)->setData(QVariantList{"first"}, Desktop);
        source.item(0)->setData(QStringList{"activity-b"}, Activity);
        source.item(2)->setData(QStringList{"activity-a"}, Activity);
        TaskRows rows(&manager);
        rows.setProperty("desktopIds", QVariantList{"second", "first"});
        rows.setProperty("activityNames", QVariantMap{{"activity-b", "Reading"}, {"activity-a", "Writing"}});
        rows.setSourceModel(&source);
        manager.configure({module}, {});
        QTRY_COMPARE(rows.rowCount(), 3);
        QCOMPARE(rows.nativeRow(0), 1);
        QCOMPARE(rows.nativeRow(1), 2);
        for (const auto &sort : {"recent", "desktop", "activity", "name"}) {
            manager.configure({module}, {{module, QVariantMap{{"sort", sort}}}});
            QCOMPARE(rows.nativeRow(1), QByteArray(sort) == "name" ? 2 : 0);
            QCOMPARE(rows.visualRow(rows.nativeRow(2)), 2);
        }
        source.item(0)->setData(true, Pinned);
        QTRY_COMPARE(manager.entries().size(), 1);
        QCOMPARE(rows.rowCount(), 3);
        QCOMPARE(rows.nativeRow(0), 0);
        manager.configure({}, {});
        QCOMPARE(rows.rowCount(), 2);
        source.item(1)->setData(false, Pinned);
        QTRY_COMPARE(rows.rowCount(), 1);
        manager.configure({module}, {});
        QTRY_COMPARE(rows.rowCount(), 3);
        source.removeRow(0);
        QTRY_COMPARE(rows.rowCount(), 2);
        QCOMPARE(rows.nativeRow(0), 1);
    }

    void migrateExistingModuleProfileOnce()
    {
        const auto path = dir.filePath("old-profile.ini");
        {
            QSettings old(path, QSettings::IniFormat);
            old.setValue("enabledModules", QStringList{id});
            old.setValue("taskSort", 3);
        }
        DockSettings upgraded(path);
        const QString module = "org.sarbalabs.unpinned";
        QCOMPARE(upgraded.values().value("enabledModules").toStringList(), QStringList({id, module}));
        QCOMPARE(upgraded.values().value("moduleSettings").toMap().value(module).toMap().value("sort"), "desktop");
        QVERIFY(upgraded.apply({{"enabledModules", QStringList{id}}}));
        QCOMPARE(DockSettings(path).values().value("enabledModules").toStringList(), QStringList{id});
    }

    void profileRoundTrip()
    {
        const auto path = dir.filePath("profiles.ini");
        const QVariantMap options{{id, QVariantMap{{"label", "First"}}}};
        DockSettings first(path);
        QCOMPARE(first.values().value("enabledModules").toStringList(), QStringList{"org.sarbalabs.unpinned"});
        QVERIFY(first.apply({{"enabledModules", QStringList{id}}, {"moduleSettings", options}}));
        DockSettings restored(path), other(path, true, nullptr, {}, "docks/2");
        QCOMPARE(restored.values().value("enabledModules").toStringList(), QStringList{id});
        QCOMPARE(restored.values().value("moduleSettings").toMap(), options);
        QCOMPARE(other.values().value("enabledModules").toStringList(), QStringList{"org.sarbalabs.unpinned"});
    }
};
QTEST_GUILESS_MAIN(ModuleManagerTest)
#include "modulemanagertest.moc"
