// SPDX-License-Identifier: GPL-2.0-or-later
#include "windowpreviewmodel.h"
#include <QStandardItemModel>
#include <QSignalSpy>
#include <QDBusConnection>
#include <QTest>

class TaskFixture : public QStandardItemModel
{
    Q_OBJECT
public:
    enum Role { IsWindow = Qt::UserRole + 1, IsGroup, Ids, Minimized, Active, Closable };
    QString activated, closed;
    TaskFixture() {
        setItemRoleNames({{Qt::DisplayRole,"display"},{Qt::DecorationRole,"decoration"},
            {IsWindow,"IsWindow"},{IsGroup,"IsGroupParent"},{Ids,"WinIdList"},
            {Minimized,"IsMinimized"},{Active,"IsActive"},{Closable,"IsClosable"}});
    }
    static QStandardItem *window(const QString &name) {
        auto *item = new QStandardItem(name);
        item->setData(true, IsWindow); item->setData(true, Closable);
        item->setData(QVariantList{name + "-uuid"}, Ids);
        return item;
    }
    Q_INVOKABLE void requestActivate(const QModelIndex &index) { activated = index.data().toString(); }
    Q_INVOKABLE void requestClose(const QModelIndex &index) { closed = index.data().toString(); }
};
class HighlightFixture : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.kde.KWin.HighlightWindow")
public:
    QList<QStringList> requests;
public Q_SLOTS:
    void highlightWindows(const QStringList &ids) { requests.append(ids); }
};

class WindowPreviewTest : public QObject
{
    Q_OBJECT
private Q_SLOTS:
    void desktopHighlightOwnership() {
        if (!qEnvironmentVariableIsSet("PND_TEST_PRIVATE_HIGHLIGHT_BUS"))
            QSKIP("This test requires the isolated CTest session bus");
        auto bus = QDBusConnection::sessionBus();
        HighlightFixture effect;
        QVERIFY(bus.registerService("org.kde.KWin.HighlightWindow"));
        QVERIFY(bus.registerObject("/org/kde/KWin/HighlightWindow", &effect, QDBusConnection::ExportAllSlots));
        WindowPreviewModel first;
        {
            WindowPreviewModel second;
            first.highlight("window-a");
            first.highlight("window-a");
            second.highlight("window-b");
            first.highlight({}); // Leaving the older dock must preserve the newer hover.
            QTRY_COMPARE(effect.requests.size(), 2);
            QCOMPARE(effect.requests.at(0), QStringList{"window-a"});
            QCOMPARE(effect.requests.at(1), QStringList{"window-b"});
        }
        QTRY_COMPARE(effect.requests.size(), 3);
        QVERIFY(effect.requests.last().isEmpty());
    }
    void groupSelectionAndActions() {
        TaskFixture source;
        auto *group = new QStandardItem("Application"); group->setData(true, TaskFixture::IsGroup);
        group->appendRow(TaskFixture::window("First")); group->appendRow(TaskFixture::window("Second"));
        source.appendRow(group);
        WindowPreviewModel preview;
        preview.select(&source, 0);
        QCOMPARE(preview.count(), 2);
        QCOMPARE(preview.data(preview.index(1), WindowPreviewModel::Title).toString(), "Second");
        QCOMPARE(preview.data(preview.index(1), WindowPreviewModel::WindowId).toString(), "Second-uuid");
        preview.activate(1); QCOMPARE(source.activated, "Second");
        preview.close(0); QCOMPARE(source.closed, "First");
        group->child(1)->setData(true, TaskFixture::Minimized);
        QTRY_VERIFY(preview.data(preview.index(1), WindowPreviewModel::Minimized).toBool());
        group->appendRow(TaskFixture::window("Third"));
        QTRY_COMPARE(preview.count(), 3);
        // An old displayed entry must not target a newly shifted/replacement row.
        group->removeRow(0);
        source.activated.clear(); preview.activate(0); QVERIFY(source.activated.isEmpty());
        preview.activate(1); QCOMPARE(source.activated, "Second");
        QTRY_COMPARE(preview.count(), 2);
        preview.activate(0); QCOMPARE(source.activated, "Second");
        group->child(0)->setData(false, TaskFixture::Closable);
        source.closed.clear(); preview.close(0); QVERIFY(source.closed.isEmpty());
    }
    void singleLauncherAndLifetime() {
        auto *source = new TaskFixture;
        source->appendRow(new QStandardItem("Launcher"));
        source->appendRow(TaskFixture::window("Window"));
        WindowPreviewModel preview;
        preview.select(source, 0); QCOMPARE(preview.count(), 0);
        preview.select(source, 1); QCOMPARE(preview.count(), 1);
        source->removeRow(0);
        preview.activate(0); QCOMPARE(source->activated, "Window");
        QSignalSpy gone(&preview, &WindowPreviewModel::targetGone);
        delete source;
        QTRY_COMPARE(preview.count(), 0);
        QVERIFY(!gone.isEmpty());
        preview.activate(0); preview.close(0); // No stale source access.
        preview.clear(); QCOMPARE(preview.count(), 0);
    }
};
QTEST_GUILESS_MAIN(WindowPreviewTest)
#include "windowpreviewtest.moc"
