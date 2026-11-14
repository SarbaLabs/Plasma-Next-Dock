// SPDX-License-Identifier: GPL-2.0-or-later
#include "layersurfaceposition.h"
#include <QEvent>
#include <qpa/qplatformwindow.h>
#include <qpa/qwindowsysteminterface.h>

LayerSurfacePosition::LayerSurfacePosition(QWindow *window) : QObject(window), m_window(window)
{
    window->installEventFilter(this);
}
void LayerSurfacePosition::setOrigin(QPoint origin)
{
    m_origin = origin;
    apply();
}
void LayerSurfacePosition::schedule()
{
    if (m_pending || m_applying) return;
    m_pending = true;
    QMetaObject::invokeMethod(this, [this] { m_pending = false; apply(); }, Qt::QueuedConnection);
}
void LayerSurfacePosition::apply()
{
    if (m_applying || !m_window || !m_window->handle()) return;
    auto *platform = m_window->handle();
    QRect geometry = platform->geometry();
    if (geometry.topLeft() == m_origin && m_window->position() == m_origin) return;
    geometry.moveTopLeft(m_origin);
    m_applying = true;
    // QWaylandWindow::setGeometry normalizes ordinary toplevel positions to the
    // output origin. Calling QWindow::setPosition cannot override that. Update
    // only Qt's coordinate bookkeeping, not the Wayland surface or its size.
    platform->QPlatformWindow::setGeometry(geometry);
    QWindowSystemInterface::handleGeometryChange<QWindowSystemInterface::SynchronousDelivery>(m_window, geometry);
    m_applying = false;
}
bool LayerSurfacePosition::eventFilter(QObject *object, QEvent *event)
{
    if (object == m_window && (event->type() == QEvent::Move || event->type() == QEvent::Resize
        || event->type() == QEvent::Show || event->type() == QEvent::PlatformSurface)) schedule();
    return false;
}
