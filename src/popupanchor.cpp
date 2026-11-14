// SPDX-License-Identifier: GPL-2.0-or-later
#include "popupanchor.h"
#include "geometry.h"
#include <QGuiApplication>
#include <QQuickWindow>
#include <QPlatformSurfaceEvent>
#include <QVariant>
#include <algorithm>

PopupAnchor::PopupAnchor(QObject *parent) : QObject(parent)
{
    qApp->installEventFilter(this);
}
void PopupAnchor::prepare(QQuickItem *item, QPointF point, int edge)
{
    if (!item || !item->window()) return;
    if (m_parentWindow != item->window()) m_popup.clear();
    m_parentWindow = item->window();
    const QPoint scene = item->mapToScene(point).toPoint();
    // xdg_positioner anchors must intersect the parent surface, even near corners.
    m_anchor = QRect(QPoint(std::clamp(scene.x(), 0, std::max(0, m_parentWindow->width() - 1)),
                           std::clamp(scene.y(), 0, std::max(0, m_parentWindow->height() - 1))), QSize(1, 1));
    switch (edge) {
    case DockGeometry::Top: m_gravity = Qt::BottomEdge; break;
    case DockGeometry::Left: m_gravity = Qt::RightEdge; break;
    case DockGeometry::Right: m_gravity = Qt::LeftEdge; break;
    default: m_gravity = Qt::TopEdge; break;
    }
    if (m_popup) apply(m_popup);
}
void PopupAnchor::apply(QWindow *popup)
{
    // Override recent Qt parentControlGeometry, which otherwise anchors a Menu to
    // the entire root Item and ignores popup(x,y). These properties also work in 6.8.
    popup->setProperty("_q_waylandPopupAnchorRect", m_anchor);
    popup->setProperty("_q_waylandPopupAnchor", QVariant::fromValue(Qt::Edges(Qt::TopEdge | Qt::LeftEdge)));
    popup->setProperty("_q_waylandPopupGravity", QVariant::fromValue(m_gravity));
    // Let KWin slide within the output, without flipping across the dock.
    popup->setProperty("_q_waylandPopupConstraintAdjustment", 8u | 16u);
}
bool PopupAnchor::eventFilter(QObject *object, QEvent *event)
{
    if (event->type() != QEvent::PlatformSurface || !m_parentWindow) return false;
    auto *surface = static_cast<QPlatformSurfaceEvent *>(event);
    auto *window = qobject_cast<QWindow *>(object);
    if (surface->surfaceEventType() == QPlatformSurfaceEvent::SurfaceCreated && window
        && window->type() == Qt::Popup) {
        // PlasmaExtras creates the widget QWindow with winId() before assigning
        // its transient parent. Apply before first mapping, not only creation.
        const auto attach = [this, window] {
            if (m_parentWindow && window->transientParent() == m_parentWindow) {
                m_popup = window;
                apply(window);
            }
        };
        attach();
        if (!window->property("_pnd_anchor_watched").toBool()) {
            window->setProperty("_pnd_anchor_watched", true);
            connect(window, &QWindow::transientParentChanged, this, attach);
        }
    }
    return false;
}
