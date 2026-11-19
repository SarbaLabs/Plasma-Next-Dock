// SPDX-License-Identifier: GPL-2.0-or-later
#include "backgroundeffects.h"
#include "controller.h"
#include "geometry.h"
#include <QGuiApplication>
#include <QPlatformSurfaceEvent>
#include <QTest>
#include <QThread>

class Recorder : public BackgroundEffects
{
public:
    explicit Recorder(QQuickWindow *window) : BackgroundEffects(window) {}
    int writes = 0, clears = 0;
    bool enabled = false, guiThread = true;
    QRegion region;
protected:
    void writeEffects(bool on, const QRegion &r) override {
        guiThread &= QThread::currentThread() == qApp->thread();
        enabled = on;
        if (!on) { ++clears; return; }
        ++writes; region = r;
    }
};
class BackgroundEffectsTest : public QObject
{
    Q_OBJECT
private Q_SLOTS:
    void geometryCacheAndModes() {
        QQuickWindow window; window.resize(400, 160); window.show();
        QVERIFY(QTest::qWaitForWindowExposed(&window));
        Recorder effects(&window);
        DockController controller(&window);
        connect(&controller, &DockController::capsuleChanged, &effects, &BackgroundEffects::setGeometry);
        const QRectF capsule(30.5, 80.5, 300, 50);
        controller.setGeometry(capsule, 10, {}, 0);
        effects.configure({{"backgroundType", 3}});
        QTRY_VERIFY(effects.enabled);
        QCOMPARE(effects.region, QRegion(DockGeometry::capsule(capsule, 10).toFillPolygon().toPolygon()));
        QVERIFY(!effects.region.contains(QPoint(31, 81)));
        const int writes = effects.writes;
        for (int i = 0; i < 20; ++i) {
            controller.setGeometry(capsule, 10, {QRectF(i, 0, 60, 60)}, 0);
            window.update();
        }
        QTest::qWait(80);
        QCOMPARE(effects.writes, writes); // Icon/input changes do not rewrite blur.
        controller.setGeometry(capsule, 0, {}, 0);
        QTRY_COMPARE(effects.writes, writes + 1);
        QVERIFY(effects.region.contains(QPoint(31, 81)));
        controller.setGeometry(capsule, 999, {}, 0);
        QTRY_COMPARE(effects.writes, writes + 2);
        QCOMPARE(effects.region, QRegion(DockGeometry::capsule(capsule, 25).toFillPolygon().toPolygon()));
        effects.configure({{"backgroundType", 4}});
        QTest::qWait(20);
        QCOMPARE(effects.writes, writes + 2); // Same blur in both modes.
        for (int mode : {0, 1, 2}) {
            effects.configure({{"backgroundType", mode}});
            QTRY_VERIFY(!effects.enabled);
        }
        effects.setGeometry(DockGeometry::capsule({}, 0));
        effects.configure({{"backgroundType", 3}});
        QTest::qWait(20); QVERIFY(!effects.enabled); // Never accidentally blur the full canvas.
        QVERIFY(effects.guiThread);
    }
    void paletteVisibilityAndSurfaceLifecycle() {
        QQuickWindow window; window.resize(300, 100); window.show();
        QVERIFY(QTest::qWaitForWindowExposed(&window));
        Recorder effects(&window);
        effects.setGeometry(DockGeometry::capsule(QRectF(20, 40, 240, 40), 10));
        effects.configure({{"backgroundType", 4}});
        QTRY_VERIFY(effects.enabled);
        for (int cycle = 0; cycle < 10; ++cycle) {
            const int writes = effects.writes;
            for (int i = 0; i < 5; ++i) {
                QEvent palette(QEvent::ApplicationPaletteChange);
                QCoreApplication::sendEvent(qApp, &palette);
            }
            QTRY_COMPARE(effects.writes, writes + 1); // Coalesced stationary restoration.
            window.hide();
            QCoreApplication::processEvents();
            const int hiddenWrites = effects.writes;
            QEvent palette(QEvent::ApplicationPaletteChange);
            QCoreApplication::sendEvent(qApp, &palette);
            QCoreApplication::processEvents();
            QCOMPARE(effects.writes, hiddenWrites);
            window.show();
            QVERIFY(QTest::qWaitForWindowExposed(&window));
            QTRY_VERIFY(effects.writes > hiddenWrites);
        }
        QPlatformSurfaceEvent destroy(QPlatformSurfaceEvent::SurfaceAboutToBeDestroyed);
        QCoreApplication::sendEvent(&window, &destroy);
        QVERIFY(!effects.enabled);
        const int writes = effects.writes;
        effects.setGeometry(DockGeometry::capsule(QRectF(30, 40, 220, 40), 0));
        QCoreApplication::processEvents();
        QCOMPARE(effects.writes, writes);
        QPlatformSurfaceEvent create(QPlatformSurfaceEvent::SurfaceCreated);
        QCoreApplication::sendEvent(&window, &create);
        QTRY_VERIFY(effects.enabled);
        QCOMPARE(effects.region.boundingRect(), QRect(30, 40, 220, 40));
        effects.configure({{"backgroundType", 0}});
        QTRY_VERIFY(!effects.enabled);
        QVERIFY(effects.guiThread);
    }
    void windowDestructionWithPendingWork() {
        auto *window = new QQuickWindow;
        Recorder effects(window);
        effects.setGeometry(DockGeometry::capsule(QRectF(0, 0, 100, 40), 10));
        effects.configure({{"backgroundType", 3}});
        delete window;
        QCoreApplication::processEvents();
        QCOMPARE(effects.writes, 0);
    }
};
QTEST_MAIN(BackgroundEffectsTest)
#include "backgroundeffectstest.moc"
