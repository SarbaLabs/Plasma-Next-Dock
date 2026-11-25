// SPDX-License-Identifier: GPL-2.0-or-later
#include "modules/modulemanager.h"
#include <KIO/RestoreJob>
#include <KCoreDirLister>
#include <QApplication>
#include <QDir>
#include <QFile>
#include <QTemporaryDir>
#include <QTest>
#include <algorithm>

class TrashModuleTest : public QObject
{
    Q_OBJECT
private Q_SLOTS:
    void dropAndRestore()
    {
        const QString module = QStringLiteral("org.sarbalabs.trash");
        ModuleManager manager({{module, {{}, QUrl::fromLocalFile(QStringLiteral(TRASH_PACKAGE) + "/Main.qml")}}});
        manager.configure({module}, {});
        QVERIFY(manager.loaded(module));
        QCOMPARE(manager.entries().size(), 1);
        const auto entry = [&] { return manager.entries().first().toMap(); };
        // trash:/ also includes other mounted volumes. Capture the baseline
        // and never trigger its aggregate empty action in an install-time test.
        KCoreDirLister listing;
        listing.setShowHiddenFiles(true);
        listing.openUrl(QUrl(QStringLiteral("trash:/")));
        QTRY_VERIFY(listing.isFinished());
        const QString originalIcon = listing.items().isEmpty() ? "user-trash" : "user-trash-full";
        QTRY_COMPARE(entry()["icon"], originalIcon);

        QTemporaryDir source(qEnvironmentVariable("XDG_DATA_HOME") + "/source-XXXXXX");
        QVERIFY(source.isValid());
        const QString name = ".pnd-" + QFileInfo(source.path()).fileName();
        QFile file(source.filePath(name));
        QVERIFY(file.open(QIODevice::WriteOnly));
        file.write("trash module test");
        file.close();
        QVERIFY(manager.dropDocuments(module, "trash", {QUrl::fromLocalFile(file.fileName())}));
        QTRY_COMPARE(entry()["icon"], "user-trash-full");
        QTRY_VERIFY(entry()["acceptsDocuments"].toBool());
        QVERIFY(!file.exists());

        const auto actions = entry()["actions"].toList();
        QVERIFY(std::any_of(actions.begin(), actions.end(), [](const QVariant &value) {
            const auto action = value.toMap();
            return action.value("id") == "empty" && action.value("enabled").toBool();
        }));
        QTRY_VERIFY(!listing.items().isEmpty());
        QUrl stored;
        for (const auto &item : listing.items())
            if (item.name() == name || item.text() == name) stored = item.url();
        QVERIFY(!stored.isEmpty());
        auto *restore = KIO::restoreFromTrash({stored}, KIO::HideProgressInfo);
        QVERIFY2(restore->exec(), qPrintable(restore->errorString()));
        QTRY_COMPARE(entry()["icon"], originalIcon);
        QVERIFY(file.open(QIODevice::ReadOnly));
        QCOMPARE(file.readAll(), "trash module test");
    }
};
QTEST_MAIN(TrashModuleTest)
#include "trashmoduletest.moc"
