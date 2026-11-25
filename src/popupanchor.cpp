// SPDX-License-Identifier: GPL-2.0-or-later
#include "popupanchor.h"
#include "geometry.h"
#include <KWindowEffects>
#include <QGuiApplication>
#include <QQuickWindow>
#include <QScreen>
#include <QPlatformSurfaceEvent>
#include <QVariant>
#include <algorithm>

PopupAnchor::PopupAnchor(QObject *parent) : QObject(parent)
{
    qApp->installEventFilter(this);
}
void PopupAnchor::prepare(QQuickItem *item, QPointF point, int edge, bool slideAcrossEdge, bool animate)
{
    Qt::Edges gravity;
    switch (edge) {
    case DockGeometry::Top: gravity = Qt::BottomEdge; break;
    case DockGeometry::Left: gravity = Qt::RightEdge; break;
    case DockGeometry::Right: gravity = Qt::LeftEdge; break;
    default: gravity = Qt::TopEdge; break;
    }
    // xdg_positioner.constraint_adjustment is a Wayland protocol bitmask.
    // Preserve the requested size at corners. When the menu fits inward its
    // shadow may overlap the dock's exclusive zone without moving the fill.
    constexpr uint slideX = 1u, slideY = 2u;
    const bool vertical = edge == DockGeometry::Left || edge == DockGeometry::Right;
    setAnchor(item, point, gravity, slideAcrossEdge ? slideX | slideY : (vertical ? slideY : slideX), animate);
}

void PopupAnchor::prepareContextMenu(QQuickItem *anchor, int edge)
{
    // Start at a corner of the click point. Let KWin flip the menu near an
    // output boundary before sliding it, so the pointer stays beside the menu.
    const Qt::Edges gravity = (edge == DockGeometry::Right ? Qt::LeftEdge : Qt::RightEdge)
        | (edge == DockGeometry::Bottom ? Qt::TopEdge : Qt::BottomEdge);
    setAnchor(anchor, {}, gravity, std::nullopt, false);
}

void PopupAnchor::setAnchor(QQuickItem *item, QPointF point, Qt::Edges gravity, std::optional<uint> constraints, bool animate)
{
    if (!item || !item->window()) return;
    if (m_parentWindow != item->window()) m_popup.clear();
    m_parentWindow = item->window();
    m_pending = true;
    m_animate = animate;
    const QPoint scene = item->mapToScene(point).toPoint();
    // xdg_positioner anchors must intersect the parent surface, even near corners.
    m_anchor = QRect(QPoint(std::clamp(scene.x(), 0, std::max(0, m_parentWindow->width() - 1)),
                           std::clamp(scene.y(), 0, std::max(0, m_parentWindow->height() - 1))), QSize(1, 1));
    m_gravity = gravity;
    m_constraints = constraints;
    if (m_popup && !m_popup->isVisible()) apply(m_popup);
}
void PopupAnchor::apply(QWindow *popup)
{
    // Override recent Qt parentControlGeometry, which otherwise anchors a Menu to
    // the entire root Item and ignores popup(x,y). These properties also work in 6.8.
    popup->setProperty("_q_waylandPopupAnchorRect", m_anchor);
    popup->setProperty("_q_waylandPopupAnchor", QVariant::fromValue(Qt::Edges(Qt::TopEdge | Qt::LeftEdge)));
    popup->setProperty("_q_waylandPopupGravity", QVariant::fromValue(m_gravity));
    uint constraints = m_constraints.value_or(0u);
    if (!m_constraints && m_parentWindow->screen()) {
        // KWin slides constrained popups out of the dock's exclusive zone.
        // Allow correction only on axes where the menu would leave the output.
        const QRect output = m_parentWindow->screen()->geometry();
        const QPoint click = m_parentWindow->mapToGlobal(m_anchor.topLeft());
        const int roomX = m_gravity.testFlag(Qt::LeftEdge) ? click.x() - output.x() : output.right() + 1 - click.x();
        const int roomY = m_gravity.testFlag(Qt::TopEdge) ? click.y() - output.y() : output.bottom() + 1 - click.y();
        constexpr uint slideFlipX = 1u | 4u, slideFlipY = 2u | 8u;
        if (popup->width() > roomX) constraints |= slideFlipX;
        if (popup->height() > roomY) constraints |= slideFlipY;
    }
    popup->setProperty("_q_waylandPopupConstraintAdjustment", constraints);
}
void PopupAnchor::attach(QWindow *window)
{
    if (!m_pending || !window || window->transientParent() != m_parentWindow) return;
    m_popup = window;
    apply(window);
    if (window->isVisible()) m_pending = false;
    if (m_animate) {
        const auto edge = m_gravity == Qt::TopEdge ? KWindowEffects::BottomEdge
            : m_gravity == Qt::BottomEdge ? KWindowEffects::TopEdge
            : m_gravity == Qt::LeftEdge ? KWindowEffects::RightEdge : KWindowEffects::LeftEdge;
        KWindowEffects::slideWindow(window, edge, -1);
    }
}

void PopupAnchor::transientParentChanged()
{
    attach(qobject_cast<QWindow *>(sender()));
}

bool PopupAnchor::eventFilter(QObject *object, QEvent *event)
{
    if (!m_pending || !m_parentWindow) return false;
    if (event->type() == QEvent::Show) {
        auto *window = qobject_cast<QWindow *>(object);
        if (window && window->type() == Qt::Popup && window->transientParent() == m_parentWindow) {
            // QMenu has its final size at show. Later menus invoked from
            // inside the launcher must keep their own positioning.
            attach(window);
            m_pending = false;
        }
        return false;
    }
    if (event->type() != QEvent::PlatformSurface) return false;
    auto *surface = static_cast<QPlatformSurfaceEvent *>(event);
    auto *window = qobject_cast<QWindow *>(object);
    if (surface->surfaceEventType() == QPlatformSurfaceEvent::SurfaceCreated && window
        && window->type() == Qt::Popup) {
        // QMenu can create its QWindow before assigning the dock parent. Each
        // dock must see that assignment, regardless of event-filter order.
        connect(window, &QWindow::transientParentChanged, this, &PopupAnchor::transientParentChanged, Qt::UniqueConnection);
        attach(window);
    }
    return false;
}
