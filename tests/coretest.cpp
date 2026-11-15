// SPDX-License-Identifier: GPL-2.0-or-later
#include "controller.h"
#include "popupanchor.h"
#include "menutarget.h"
#include <QStandardItemModel>
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
    void persistentMenuTarget() {
        QStandardItemModel model;
        model.setItemRoleNames({{Qt::DisplayRole, "display"}});
        model.appendRow(new QStandardItem("First"));
        model.appendRow(new QStandardItem("Second"));
        MenuTarget target;
        target.bind(&model, 1);
        QCOMPARE(target.data("display").toString(), QString("Second"));
        model.removeRow(0);
        QCOMPARE(target.index().row(), 0);
        QCOMPARE(target.data("display").toString(), QString("Second"));
        QSignalSpy removed(&target, &MenuTarget::invalidated);
        model.removeRow(0);
        QVERIFY(!target.valid());
        QCOMPARE(removed.count(), 1);
        model.appendRow(new QStandardItem("Replacement"));
        QVERIFY(!target.valid());
        QVERIFY(!target.data("display").isValid());
    }
    void widgetPopupLateTransientParent() {
        QQuickWindow dock;
        dock.resize(300, 400);
        PopupAnchor anchor;
        anchor.prepare(dock.contentItem(), QPointF(50, 70), 2);
        QWindow popup;
        popup.setFlags(Qt::Popup);
        popup.create(); // PlasmaExtras/QMenu calls winId before setting the parent.
        QVERIFY(!popup.property("_q_waylandPopupAnchorRect").isValid());
        popup.setTransientParent(&dock);
        QCOMPARE(popup.property("_q_waylandPopupAnchorRect").toRect(), QRect(50,70,1,1));
    }

    void nativePopupAnchorLifecycle() {
        QQuickWindow dock;
        dock.resize(300, 400);
        PopupAnchor anchor;
        QWindow popup;
        popup.setFlags(Qt::Popup);
        popup.setTransientParent(&dock);
        const Qt::Edges gravity[] = {Qt::TopEdge, Qt::BottomEdge, Qt::RightEdge, Qt::LeftEdge};
        for (int edge = 0; edge < 4; ++edge) {
            anchor.prepare(dock.contentItem(), QPointF(80, 120 + edge * 20), edge);
            popup.create();
            QCOMPARE(popup.property("_q_waylandPopupAnchorRect").toRect(), QRect(80, 120 + edge * 20, 1, 1));
            QCOMPARE(popup.property("_q_waylandPopupGravity").value<Qt::Edges>(), gravity[edge]);
            QCOMPARE(popup.property("_q_waylandPopupConstraintAdjustment").toUInt(), 24u);
        }
        // Reuse and recreation must both pick up the new click, not the first one.
        popup.destroy();
        anchor.prepare(dock.contentItem(), QPointF(-10, 999), 2);
        popup.create();
        QCOMPARE(popup.property("_q_waylandPopupAnchorRect").toRect(), QRect(0, 399, 1, 1));
        QQuickWindow settings;
        QWindow unrelated;
        unrelated.setFlags(Qt::Popup);
        unrelated.setTransientParent(&settings);
        unrelated.create();
        QVERIFY(!unrelated.property("_q_waylandPopupAnchorRect").isValid());
    }
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
    void edgeCorridorCoversRecallSpanWithoutChangingCollision() {
        const QRect bounds(0, 0, 400, 400);
        // Different gaps ensure the corridor is derived from capsule geometry.
        for (int gap : {0, 8, 30}) {
            for (int e = 0; e < 4; ++e) {
                const auto edge = static_cast<DockGeometry::Edge>(e);
                QRectF bar(100, 100, 200, 60);
                QPoint outer, corner;
                switch (edge) {
                case DockGeometry::Bottom:
                    bar.moveBottom(400 - gap); outer = QPoint(200, 399); corner = QPoint(100, 399); break;
                case DockGeometry::Top:
                    bar.moveTop(gap); outer = QPoint(200, 0); corner = QPoint(100, 0); break;
                case DockGeometry::Left:
                    bar = QRectF(gap, 100, 60, 200); outer = QPoint(0, 200); corner = QPoint(0, 100); break;
                case DockGeometry::Right:
                    bar = QRectF(340 - gap, 100, 60, 200); outer = QPoint(399, 200); corner = QPoint(399, 100); break;
                }
                const auto input = DockGeometry::inputRegion(bar, 20, {}, bounds, edge);
                QVERIFY(input.contains(outer));
                QVERIFY(input.contains(corner));
                QVERIFY(!input.contains(QPoint(200, 200)));
                if (gap > 0) {
                    QVERIFY(!DockGeometry::overlaps(QRectF(outer, QSizeF(1, 1)), bar, 20));
                }
                const QPoint end = e < 2 ? QPoint(0, outer.y()) : QPoint(outer.x(), 0);
                QVERIFY(input.contains(end)); // Recall span must work even at zero gap.
                QCOMPARE(input.intersected(bounds), input);
            }
        }
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
        dock.setAttention(true);
        QTRY_VERIFY(!dock.hideRequested());
        dock.setAttention(false);
        QTRY_VERIFY(dock.hideRequested());
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
