// SPDX-License-Identifier: GPL-2.0-or-later
#include "controller.h"
#include "popupanchor.h"
#include "menutarget.h"
#include <QStandardItemModel>
#include <QTest>
#include <QSignalSpy>
#include <QMouseEvent>

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
    void signedCornersFollowTheDockAxis() {
        const auto horizontal = DockGeometry::capsule({0, 0, 160, 40}, {12, 0, -15, -20}, false);
        QVERIFY(!horizontal.contains({1, 1}));
        QVERIFY(horizontal.contains({159, 1}));
        QVERIFY(horizontal.contains({-8, 39}));
        QVERIFY(!horizontal.contains({-8, 28}));
        QVERIFY(horizontal.contains({165, 39}));
        const auto vertical = DockGeometry::capsule({0, 0, 40, 160}, {-20, 0, 10, -20}, true);
        QVERIFY(vertical.contains({1, -8}));
        QVERIFY(!vertical.contains({14, -8}));
        QVERIFY(vertical.contains({1, 168}));
    }
    void windowPointerIgnoresChildHoverAndRepeatedPositions() {
        QQuickWindow window;
        window.resize(400, 200);
        window.show();
        QCoreApplication::processEvents();
        DockController dock(&window);
        dock.setPointerTarget(window.contentItem());
        dock.setGeometry(QRectF(50, 140, 300, 50), 10, {QRectF(100, 70, 60, 130)});
        QSignalSpy moves(&dock, &DockController::pointerPositionChanged);
        const auto move = [&](QPointF position) {
            QMouseEvent event(QEvent::MouseMove, position, position, Qt::NoButton, Qt::MiddleButton, Qt::NoModifier);
            QCoreApplication::sendEvent(&window, &event);
        };
        move(QPointF(130, 125));
        QVERIFY(dock.pointerHovered());
        QCOMPARE(moves.count(), 1);
        // Qt Quick's geometry-triggered hover re-delivery is not a physical exit.
        QEvent hoverLeave(QEvent::HoverLeave);
        QCoreApplication::sendEvent(&window, &hoverLeave);
        move(QPointF(130, 125));
        QVERIFY(dock.pointerHovered());
        QCOMPARE(moves.count(), 1);
        move(QPointF(130, 199.75)); // Fractional HiDPI edge coordinates stay inside.
        QVERIFY(dock.pointerHovered());
        move(QPointF(20, 20)); // Transparent interior margin is not hover.
        QVERIFY(!dock.pointerHovered());
        move(QPointF(130, 125));
        QEvent leave(QEvent::Leave);
        QCoreApplication::sendEvent(&window, &leave);
        QVERIFY(!dock.pointerHovered());
        dock.setPointerTarget(nullptr);
        move(QPointF(130, 125));
        QVERIFY(!dock.pointerHovered());
    }
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

    void pointerMenuWithMultipleDocks() {
        QQuickWindow dock, otherDock;
        dock.resize(300, 400);
        QQuickItem click(dock.contentItem());
        click.setPosition({40, 50});
        PopupAnchor owner, other;
        owner.prepareContextMenu(&click, DockGeometry::Top);
        other.prepareContextMenu(otherDock.contentItem(), DockGeometry::Bottom);
        QWindow popup;
        popup.setFlags(Qt::Popup);
        popup.resize(50, 60);
        popup.create();
        popup.setTransientParent(&dock);
        QCOMPARE(popup.property("_q_waylandPopupAnchorRect").toRect(), QRect(40, 50, 1, 1));
        QCOMPARE(popup.property("_q_waylandPopupGravity").value<Qt::Edges>(), Qt::RightEdge | Qt::BottomEdge);
        QCOMPARE(popup.property("_q_waylandPopupConstraintAdjustment").toUInt(), 0u);
        // Permit flipping/sliding along the overflowing axis only.
        popup.resize(50, 2000);
        owner.prepareContextMenu(&click, DockGeometry::Top);
        QCOMPARE(popup.property("_q_waylandPopupConstraintAdjustment").toUInt(), 10u);
    }

    void popupShadowPassesPointerInput() {
        QQuickWindow dock;
        dock.resize(450, 300);
        DockController controller(&dock);
        QQuickWindow popup;
        popup.setFlags(Qt::Popup);
        popup.resize(400, 240);
        QQuickItem surface(popup.contentItem());
        surface.setPosition({25, 25});
        surface.setSize({350, 190});
        const QList<qreal> corners{24, 0, -18, 0};
        controller.updatePopupSurface(&surface, corners, false, 3, false);
        const auto mask = popup.mask();
        QVERIFY(mask.contains({200, 100}));    // Menu content
        QVERIFY(mask.contains({200, 217}));    // Outer border
        QVERIFY(mask.contains({380, 214}));    // Inverse corner
        QVERIFY(!mask.contains({27, 27}));     // Rounded corner cutout
        QVERIFY(!mask.contains({200, 230}));   // Shadow towards the dock
        surface.setSize({260, 190});
        controller.updatePopupSurface(&surface, corners, false, 3, false);
        QVERIFY(!popup.mask().contains({330, 100}));
        QVERIFY(dock.mask().isEmpty());
    }

    void popupResizeTracksTheReleaseOutsideItsWindow() {
        QQuickWindow dock;
        DockController controller(&dock);
        QQuickWindow popup;
        popup.setFlags(Qt::Popup);
        popup.setTransientParent(&dock);
        popup.resize(400, 240);
        QQuickItem surface(popup.contentItem());
        surface.setSize({400, 240});
        controller.updatePopupSurface(&surface, {0, 0, 0, 0}, false, 0, false);
        QQuickItem grip(&surface);
        grip.setPosition({392, 0});
        grip.setSize({8, 240});
        const QPointF press(6, 120);
        controller.beginPopupResize(&grip, press);
        QSignalSpy moved(&controller, &DockController::popupResizeMoved);
        QSignalSpy finished(&controller, &DockController::popupResizeFinished);
        const QPointF delta(120, -35);
        QMouseEvent release(QEvent::MouseButtonRelease, grip.mapToScene(press) + delta, grip.mapToGlobal(press) + delta,
                            Qt::LeftButton, Qt::NoButton, Qt::NoModifier);
        QCoreApplication::sendEvent(&popup, &release);
        QCOMPARE(moved.count(), 1);
        QCOMPARE(moved.first().first().toPointF(), delta);
        QCOMPARE(finished.count(), 1);
        QVERIFY(finished.first().first().toBool());
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
            QCOMPARE(popup.property("_q_waylandPopupConstraintAdjustment").toUInt(), 3u);
            anchor.prepare(dock.contentItem(), QPointF(0, 0), edge, false);
            QCOMPARE(popup.property("_q_waylandPopupConstraintAdjustment").toUInt(), edge < 2 ? 1u : 2u);
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
        for (auto edge : {DockGeometry::Bottom, DockGeometry::Top, DockGeometry::Left, DockGeometry::Right}) {
            const QRect start = DockGeometry::surface(screen, size, edge, DockGeometry::Start);
            const QRect end = DockGeometry::surface(screen, size, edge, DockGeometry::End);
            QCOMPARE(edge < DockGeometry::Left ? start.left() : start.top(), edge < DockGeometry::Left ? screen.left() : screen.top());
            QCOMPARE(edge < DockGeometry::Left ? end.right() : end.bottom(), edge < DockGeometry::Left ? screen.right() : screen.bottom());
        }
        QVERIFY(screen.contains(DockGeometry::surface(screen, QSize(9000,9000), DockGeometry::Bottom)));
    }
    void alignmentMarginStaysOnTheSelectedEnd() {
        using namespace DockGeometry;
        const QSize output(600, 400), canvas(560, 300);
        QCOMPARE(alignmentMargins(output, canvas, Bottom, Start, 32), QMargins(32, 0, 0, 0));
        QCOMPARE(alignmentMargins(output, canvas, Top, End, 80), QMargins(0, 0, 40, 0));
        QCOMPARE(alignmentMargins(output, canvas, Right, Start, 64), QMargins(0, 64, 0, 0));
        QCOMPARE(alignmentMargins(output, canvas, Left, End, 80), QMargins(0, 0, 0, 80));
        QCOMPARE(alignmentMargins(output, canvas, Right, Center, 64), QMargins());
    }
    void roundedContactAndInputAreIndependentOfCanvas() {
        const QRectF bar(100, 100, 300, 50);
        QVERIFY(!DockGeometry::capsule(bar, 10).intersects(QRectF(110, 20, 100, 60))); // Drawing margin only.
        QVERIFY(DockGeometry::capsule(bar, 10).intersects(QRectF(110, 20, 100, 90)));
        QVERIFY(!DockGeometry::capsule(bar, 20).intersects(QRectF(100,100,1,1)));
        QVERIFY(DockGeometry::capsule(bar, 0).intersects(QRectF(100,100,1,1)));
        QCOMPARE(DockGeometry::capsule(bar, 900).boundingRect(), bar);
        const auto region = DockGeometry::inputRegion(bar, DockGeometry::capsule(bar, 10), {QRectF(120,70,60,60)}, QRect(0,0,600,200));
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
                const auto input = DockGeometry::inputRegion(bar, DockGeometry::capsule(bar, 20), {}, bounds, edge);
                QVERIFY(input.contains(outer));
                QVERIFY(input.contains(corner));
                QVERIFY(!input.contains(QPoint(200, 200)));
                if (gap > 0) {
                    QVERIFY(!DockGeometry::capsule(bar, 20).intersects(QRectF(outer, QSizeF(1, 1))));
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
        dock.setVisibility(DockGeometry::WindowsGoBelow);
        QVERIFY(!dock.hideRequested());
    }
    void freeDodgeStopsAtBothDockEnds() {
        DockController dock;
        WindowModel model;
        dock.setModel(&model);
        dock.setEdgeAvailable(true);
        const QPoint origin(-600, 80);
        dock.setSurfaceOrigin(origin);
        for (bool vertical : {false, true}) {
            const QRectF footprint = vertical ? QRectF(0, 150, 65, 200) : QRectF(150, 0, 200, 65);
            const QRectF capsule = vertical ? QRectF(0, 150, 4, 200) : QRectF(150, 0, 200, 4);
            dock.setGeometry(capsule, 0, {}, vertical ? DockGeometry::Left : DockGeometry::Top, {}, {}, footprint);
            for (int along : {149, 150, 349, 350}) {
                const QPoint point = vertical ? QPoint(64, along) : QPoint(along, 64);
                model.rect = QRectF(origin + point, QSize(1, 1));
                model.changed();
                QCoreApplication::processEvents();
                QCOMPARE(dock.hideRequested(), along >= 150 && along < 350);
            }
            model.rect = QRectF(origin + footprint.center(), QSize(1, 1));
            model.changed();
            QTRY_VERIFY(dock.hideRequested());
            dock.setGeometry(capsule, 0, {});
            QTRY_VERIFY(!dock.hideRequested());
        }
    }
    void autoHideWithoutOverlap() {
        DockController dock;
        dock.setVisibility(DockGeometry::AutoHide);
        QVERIFY(!dock.hideRequested());
        dock.setEdgeAvailable(true);
        QVERIFY(dock.hideRequested());
        dock.setHovered(true);
        QVERIFY(!dock.hideRequested());
        dock.setHovered(false);
        QTRY_VERIFY(dock.hideRequested());
        dock.setVisibility(DockGeometry::DodgeWindows);
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
