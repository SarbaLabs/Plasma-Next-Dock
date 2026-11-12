// SPDX-License-Identifier: GPL-2.0-or-later
#include "controller.h"
#include <QTest>
#include <QSignalSpy>

class WindowModel : public QAbstractListModel
{
public:
    enum { Geometry = Qt::UserRole + 1, IsWindow, IsMinimized };
    QRectF rect;
    bool minimized = false;
    bool window = true;
    int rowCount(const QModelIndex &parent = {}) const override { return parent.isValid() ? 0 : 1; }
    QHash<int, QByteArray> roleNames() const override { return {{Geometry,"Geometry"},{IsWindow,"IsWindow"},{IsMinimized,"IsMinimized"}}; }
    QVariant data(const QModelIndex &, int role) const override {
        if (role == Geometry) return rect;
        if (role == IsWindow) return window;
        if (role == IsMinimized) return minimized;
        return {};
    }
    void changed() { Q_EMIT dataChanged(index(0), index(0)); }
};
class CoreTest : public QObject
{
    Q_OBJECT
private Q_SLOTS:
    void allEdgesAndNegativeOutputOrigin() {
        const QRect screen(-1920, 120, 1920, 1080);
        const QSize size(600, 100);
        QCOMPARE(DockGeometry::surface(screen, size, DockGeometry::Bottom).bottom(), screen.bottom());
        QCOMPARE(DockGeometry::surface(screen, size, DockGeometry::Top).top(), screen.top());
        QCOMPARE(DockGeometry::surface(screen, size, DockGeometry::Left).left(), screen.left());
        QCOMPARE(DockGeometry::surface(screen, size, DockGeometry::Right).right(), screen.right());
        QVERIFY(screen.contains(DockGeometry::surface(screen, QSize(9000,9000), DockGeometry::Bottom)));
    }
    void roundedContactAndInputAreIndependentOfCanvas() {
        const QRectF bar(100, 100, 300, 50);
        QVERIFY(!DockGeometry::overlaps(QRectF(110, 20, 100, 60), bar, 10)); // Drawing margin only.
        QVERIFY(DockGeometry::overlaps(QRectF(110, 20, 100, 90), bar, 10));
        QVERIFY(!DockGeometry::overlaps(QRectF(100,100,1,1), bar, 20));
        QVERIFY(DockGeometry::overlaps(QRectF(100,100,1,1), bar, 0));
        QCOMPARE(DockGeometry::capsule(bar, 900).boundingRect(), bar);
        const auto region = DockGeometry::inputRegion(bar, 10, {QRectF(120,70,60,60)}, QRect(0,0,600,200));
        QVERIFY(region.contains(QPoint(140,80))); // Enlarged icon remains clickable.
        QVERIFY(region.contains(QPoint(250,120)));
        QVERIFY(!region.contains(QPoint(20,20))); // Transparent margins pass through.
    }
    void dodgeUsesVisibleCapsuleAndFailsOpen() {
        DockController dock;
        WindowModel model;
        dock.setModel(&model);
        dock.setSurfaceOrigin(QPoint(-500, 100));
        dock.setGeometry(QRectF(100,100,300,50), 10, {});
        model.rect = QRectF(-390,110,100,70);
        model.changed();
        QTest::qWait(1);
        QVERIFY(!dock.overlapping());
        model.rect.setHeight(110);
        model.changed();
        QTRY_VERIFY(dock.overlapping());
        QVERIFY(!dock.hideRequested()); // No recall capability: never strand the dock.
        dock.setEdgeAvailable(true);
        QVERIFY(dock.hideRequested());
        dock.setHovered(true);
        QVERIFY(!dock.hideRequested());
        dock.setHovered(false);
        QVERIFY(!dock.hideRequested());
        QTRY_VERIFY(dock.hideRequested());
        model.minimized = true; model.changed();
        QTRY_VERIFY(!dock.overlapping());
        model.minimized = false; model.window = false; model.changed();
        QTest::qWait(1); QVERIFY(!dock.overlapping());
        model.window = true; model.changed();
        QTRY_VERIFY(dock.hideRequested());
        dock.setDodgeEnabled(false);
        QVERIFY(!dock.hideRequested());
    }
    void coalescesAndHandlesModelLifetime() {
        DockController dock;
        auto *model = new WindowModel;
        dock.setModel(model);
        dock.setGeometry(QRectF(0,0,100,50), 0, {});
        dock.setEdgeAvailable(true);
        model->rect = QRectF(0,0,20,20);
        QSignalSpy changes(&dock, &DockController::stateChanged);
        for (int i = 0; i < 30; ++i) model->changed();
        QTRY_VERIFY(dock.hideRequested());
        QCOMPARE(changes.count(), 1);
        delete model;
        QTRY_VERIFY(!dock.hideRequested());
        QCOMPARE(dock.model(), nullptr);
    }
};
QTEST_MAIN(CoreTest)
#include "coretest.moc"
