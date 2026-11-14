// SPDX-License-Identifier: GPL-2.0-or-later
#include "layersurfaceposition.h"
#include "geometry.h"
#include <QTest>
#include <QWindow>
#include <qpa/qplatformwindow.h>
#include <qpa/qwindowsysteminterface.h>

class LayerPositionTest : public QObject
{
    Q_OBJECT
private Q_SLOTS:
    void knownOriginSurvivesConfigure() {
        for (const QRect screen : {QRect(0, 0, 2560, 1440), QRect(-1920, 140, 1920, 1080)}) {
            for (int edge = 0; edge < 4; ++edge) {
                QWindow window;
                const QSize size = edge < 2 ? QSize(900, 180) : QSize(180, 900);
                window.resize(size);
                LayerSurfacePosition position(&window);
                QPoint origin = DockGeometry::surface(screen, size, DockGeometry::Edge(edge)).topLeft();
                position.setOrigin(origin); // Also safe before native surface creation.
                window.create();
                QTRY_COMPARE(window.position(), origin);
                QCOMPARE(window.mapToGlobal(QPoint(30, 40)), origin + QPoint(30, 40));
                // Model Qt Wayland's normalization on a subsequent configure.
                auto *platform = window.handle();
                const QRect normalized(screen.topLeft(), size);
                platform->QPlatformWindow::setGeometry(normalized);
                QWindowSystemInterface::handleGeometryChange<QWindowSystemInterface::SynchronousDelivery>(&window, normalized);
                QTRY_COMPARE(window.position(), origin);
                QCOMPARE(window.size(), size);
                origin += QPoint(17, -23);
                position.setOrigin(origin);
                QCOMPARE(window.position(), origin);
                window.destroy();
                position.setOrigin(origin + QPoint(2, 3));
                window.create();
                QTRY_COMPARE(window.position(), origin + QPoint(2, 3));
            }
        }
    }
};
QTEST_MAIN(LayerPositionTest)
#include "layerpositiontest.moc"
