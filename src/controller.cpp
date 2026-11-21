// SPDX-License-Identifier: GPL-2.0-or-later
#include "controller.h"
#include <QMouseEvent>
#include <QEnterEvent>
#include <QtMath>

DockController::DockController(QQuickWindow *window, QObject *parent)
    : QObject(parent), m_window(window)
{
    m_leaveTimer.setSingleShot(true);
    m_leaveTimer.setInterval(180);
    connect(&m_leaveTimer, &QTimer::timeout, this, &DockController::evaluate);
}
// Observe window events before Qt Quick routes hover through moving tooltip/icon
// items. Never grab or consume input, and never query the global cursor in a timer.
void DockController::setPointerTarget(QQuickItem *target)
{
    if (m_pointerTarget == target) return;
    for (const auto &connection : m_pointerConnections) disconnect(connection);
    m_pointerConnections.clear();
    m_pointerTarget = target;
    attachPointerWindow(target ? target->window() : nullptr);
    if (!target) return;
    m_pointerConnections << connect(target, &QQuickItem::windowChanged, this, &DockController::attachPointerWindow)
        << connect(target, &QObject::destroyed, this, [this] { attachPointerWindow(nullptr); });
}
void DockController::attachPointerWindow(QQuickWindow *window)
{
    if (m_pointerWindow) m_pointerWindow->removeEventFilter(this);
    m_pointerWindow = window;
    m_pointerPresent = false;
    updatePointerHover();
    if (window) window->installEventFilter(this);
}
bool DockController::eventFilter(QObject *watched, QEvent *event)
{
    if (watched != m_pointerWindow || !m_pointerTarget) return false;
    QPointF position;
    bool positional = false;
    switch (event->type()) {
    case QEvent::Enter:
        position = static_cast<QEnterEvent *>(event)->position();
        positional = true;
        break;
    case QEvent::MouseMove:
    case QEvent::MouseButtonPress:
    case QEvent::MouseButtonRelease:
        position = static_cast<QMouseEvent *>(event)->position();
        positional = true;
        break;
    case QEvent::Leave:
    case QEvent::Hide:
        m_pointerPresent = false;
        updatePointerHover();
        break;
    default: break;
    }
    if (positional) {
        m_pointerPresent = true;
        const auto local = m_pointerTarget->mapFromScene(position);
        // Geometry-only hover re-delivery must not feed animated slot positions
        // back into the magnification falloff. Only a changed position does so.
        const bool moved = local != m_pointerPosition;
        m_pointerPosition = local;
        updatePointerHover();
        if (moved || event->type() == QEvent::Enter) Q_EMIT pointerPositionChanged();
    }
    return false;
}
void DockController::updatePointerHover()
{
    const bool hovered = m_pointerPresent && m_pointerTarget
        && m_lastInput.contains(QPoint(qFloor(m_pointerPosition.x()), qFloor(m_pointerPosition.y())));
    if (hovered == m_pointerHovered) return;
    m_pointerHovered = hovered;
    Q_EMIT pointerHoveredChanged();
}
void DockController::setModel(QAbstractItemModel *model)
{
    if (m_model == model) return;
    for (const auto &c : m_connections) disconnect(c);
    m_connections.clear();
    m_model = model;
    if (model) {
        auto update = [this] { scheduleEvaluation(); };
        m_connections << connect(model, &QAbstractItemModel::dataChanged, this, update)
                      << connect(model, &QAbstractItemModel::rowsInserted, this, update)
                      << connect(model, &QAbstractItemModel::rowsRemoved, this, update)
                      << connect(model, &QAbstractItemModel::modelReset, this, update)
                      << connect(model, &QAbstractItemModel::layoutChanged, this, update)
                      << connect(model, &QObject::destroyed, this, update);
    }
    Q_EMIT modelChanged();
    scheduleEvaluation();
}
void DockController::setSurfaceOrigin(QPoint origin)
{
    if (origin == m_origin) return;
    m_origin = origin;
    scheduleEvaluation();
}
QVariantMap DockController::capsuleDrawing(QSizeF size, const QList<qreal> &corners, bool vertical, qreal border) const
{
    const auto fill = DockGeometry::capsule(QRectF(QPointF(), size), corners, vertical);
    QString outline;
    if (border > 0 && !fill.isEmpty()) {
        // Boolean path operations flatten curves. Work at higher precision
        // so the exterior ring stays smooth on scaled outputs.
        const auto scale = QTransform::fromScale(8, 8);
        const auto large = scale.map(fill);
        QPainterPathStroker stroke;
        stroke.setWidth(16 * border);
        stroke.setJoinStyle(Qt::RoundJoin);
        outline = DockGeometry::svgPath(scale.inverted().map(stroke.createStroke(large).subtracted(large)));
    }
    return {{"fill", DockGeometry::svgPath(fill)}, {"outline", outline}};
}
void DockController::setGeometry(QRectF rect, qreal radius, QVariantList icons, int edge, const QList<qreal> &corners, QRectF interactionBounds)
{
    QList<QRectF> iconRects;
    for (const auto &icon : icons) iconRects << icon.toRectF();
    const QSize bounds = m_pointerTarget ? m_pointerTarget->size().toSize()
        : (m_window ? m_window->size() : QSize());
    const auto shape = corners.size() == 4 ? DockGeometry::capsule(rect, corners, edge >= DockGeometry::Left) : DockGeometry::capsule(rect, radius);
    const QRect canvas(QPoint(), bounds);
    const QRect hitBounds = interactionBounds.isEmpty() ? canvas : interactionBounds.toAlignedRect().intersected(canvas);
    const QRegion input = DockGeometry::inputRegion(rect, radius, iconRects,
        hitBounds, static_cast<DockGeometry::Edge>(edge), shape);
    if (input != m_lastInput) {
        m_lastInput = input;
        // Under Qt Wayland this is the surface input region, not a rendering clip.
        if (m_window) m_window->setMask(input);
        updatePointerHover();
    }
    if (shape == m_shape) return;
    m_shape = shape;
    Q_EMIT capsuleChanged(shape);
    // Zoom changes capsule bounds during hover; test the final geometry on leave.
    if (!m_hovered && !m_leaveTimer.isActive()) scheduleEvaluation();
}
void DockController::setHovered(bool hovered)
{
    if (hovered == m_hovered) return;
    m_hovered = hovered;
    if (hovered) {
        m_leaveTimer.stop();
        evaluate();
    } else {
        m_leaveTimer.start();
    }
}
void DockController::setEdgeAvailable(bool value)
{
    if (value == m_edgeAvailable) return;
    m_edgeAvailable = value;
    evaluate();
    Q_EMIT stateChanged();
}
void DockController::setVisibility(DockGeometry::Visibility value)
{
    m_visibility = value;
    evaluate();
}
void DockController::setAttention(bool attention)
{
    if (m_attention == attention) return;
    m_attention = attention;
    scheduleEvaluation();
}
void DockController::scheduleEvaluation()
{
    if (m_queued) return;
    m_queued = true;
    QMetaObject::invokeMethod(this, [this] { m_queued = false; evaluate(); }, Qt::QueuedConnection);
}
void DockController::evaluate()
{
    bool overlap = false;
    if (m_model) {
        const auto roles = m_model->roleNames();
        const int geometryRole = roles.key("Geometry", -1);
        const int windowRole = roles.key("IsWindow", -1);
        const int minimizedRole = roles.key("IsMinimized", -1);
        const auto globalCapsule = m_shape.translated(m_origin);
        // An ungrouped TasksModel, already filtered by desktop/activity, is required.
        if (geometryRole >= 0 && windowRole >= 0 && minimizedRole >= 0) {
            for (int row = 0; row < m_model->rowCount(); ++row) {
                const auto index = m_model->index(row, 0);
                if (!index.data(windowRole).toBool() || index.data(minimizedRole).toBool()) continue;
                const QRectF window = index.data(geometryRole).toRectF();
                if (!window.isEmpty() && globalCapsule.intersects(window)) {
                    overlap = true;
                    break;
                }
            }
        }
    }
    const bool hide = (m_visibility == DockGeometry::AutoHide || (m_visibility == DockGeometry::DodgeWindows && overlap))
        && m_edgeAvailable && !m_attention && !m_hovered && !m_leaveTimer.isActive();
    if (overlap == m_overlapping && hide == m_hideRequested) return;
    m_overlapping = overlap;
    m_hideRequested = hide;
    Q_EMIT stateChanged();
}
