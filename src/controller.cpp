// SPDX-License-Identifier: GPL-2.0-or-later
#include "controller.h"
#include "backgroundeffects.h"
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
    if (m_modulePopup && (watched == m_modulePopup || watched == m_pointerWindow)
        && filterPopupEvent(watched, event)) return true;
    if (watched != m_pointerWindow || !m_pointerTarget) return false;
    QPointF position;
    switch (event->type()) {
    case QEvent::Enter:
        position = static_cast<QEnterEvent *>(event)->position();
        break;
    case QEvent::MouseMove:
    case QEvent::MouseButtonPress:
    case QEvent::MouseButtonRelease:
        position = static_cast<QMouseEvent *>(event)->position();
        break;
    case QEvent::Leave:
    case QEvent::Hide:
        m_pointerPresent = false;
        updatePointerHover();
        return false;
    default:
        return false;
    }

    // Ignore duplicate coordinates generated as animated items pass under the pointer.
    const auto local = m_pointerTarget->mapFromScene(position);
    const bool moved = local != m_pointerPosition;
    m_pointerPresent = true;
    m_pointerPosition = local;
    updatePointerHover();
    if (moved || event->type() == QEvent::Enter) Q_EMIT pointerPositionChanged();
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
    return DockGeometry::capsuleDrawing(size, corners, vertical, border);
}
void DockController::setGeometry(QRectF rect, qreal radius, QVariantList icons, int edge, const QList<qreal> &corners, QRectF interactionBounds, QRectF dodgeBounds)
{
    QList<QRectF> iconRects;
    for (const auto &icon : icons) iconRects << icon.toRectF();
    const QSize bounds = m_pointerTarget ? m_pointerTarget->size().toSize()
        : (m_window ? m_window->size() : QSize());
    const auto shape = corners.size() == 4 ? DockGeometry::capsule(rect, corners, edge >= DockGeometry::Left) : DockGeometry::capsule(rect, radius);
    const QRect canvas(QPoint(), bounds);
    const QRect hitBounds = interactionBounds.isEmpty() ? canvas : interactionBounds.toAlignedRect().intersected(canvas);
    const QRegion input = DockGeometry::inputRegion(rect, shape, iconRects,
        hitBounds, static_cast<DockGeometry::Edge>(edge));
    if (input != m_lastInput) {
        m_lastInput = input;
        // Under Qt Wayland this is the surface input region, not a rendering clip.
        if (m_window) m_window->setMask(input);
        updatePointerHover();
    }
    const bool capsuleChangedShape = shape != m_shape;
    if (capsuleChangedShape) {
        m_shape = shape;
        Q_EMIT capsuleChanged(shape);
    }
    if (dodgeBounds == m_dodgeBounds && (!dodgeBounds.isEmpty() || !capsuleChangedShape)) return;
    m_dodgeBounds = dodgeBounds;
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
// The collision model is ungrouped and already filtered to the current activity
// and desktop. Test the dock footprint in compositor coordinates.
bool DockController::overlapsVisibleWindow() const
{
    if (!m_model) return false;
    const auto roles = m_model->roleNames();
    const int geometryRole = roles.key("Geometry", -1);
    const int windowRole = roles.key("IsWindow", -1);
    const int minimizedRole = roles.key("IsMinimized", -1);
    if (geometryRole < 0 || windowRole < 0 || minimizedRole < 0) return false;

    const auto bounds = m_dodgeBounds.translated(m_origin);
    const auto capsule = bounds.isEmpty() ? m_shape.translated(m_origin) : QPainterPath{};
    for (int row = 0; row < m_model->rowCount(); ++row) {
        const auto index = m_model->index(row, 0);
        if (!index.data(windowRole).toBool() || index.data(minimizedRole).toBool()) continue;
        const QRectF window = index.data(geometryRole).toRectF();
        if (!window.isEmpty() && (bounds.isEmpty() ? capsule.intersects(window) : bounds.intersects(window))) return true;
    }
    return false;
}

void DockController::evaluate()
{
    const bool overlap = overlapsVisibleWindow();
    const bool hide = (m_visibility == DockGeometry::AutoHide || (m_visibility == DockGeometry::DodgeWindows && overlap))
        && m_edgeAvailable && !m_attention && !m_hovered && !m_leaveTimer.isActive();
    if (overlap == m_overlapping && hide == m_hideRequested) return;
    m_overlapping = overlap;
    m_hideRequested = hide;
    Q_EMIT stateChanged();
}

bool DockController::filterPopupEvent(QObject *watched, QEvent *event)
{
    if (event->type() == QEvent::Hide && m_resizingPopup) {
        m_resizingPopup = false;
        Q_EMIT popupResizeFinished(false);
    }
    if (event->type() != QEvent::MouseMove && event->type() != QEvent::MouseButtonPress
        && event->type() != QEvent::MouseButtonRelease) return false;

    const auto *mouse = static_cast<QMouseEvent *>(event);
    if (m_resizingPopup) {
        // Qt 6.8 drops Quick grabs while forwarding popup moves. Track the
        // window events through release even if the pointer outruns the resize.
        if (event->type() == QEvent::MouseMove && mouse->buttons().testFlag(Qt::LeftButton)) {
            Q_EMIT popupResizeMoved(mouse->globalPosition() - m_resizePress);
            return true;
        }
        if (event->type() == QEvent::MouseButtonRelease && mouse->button() == Qt::LeftButton) {
            m_resizingPopup = false;
            Q_EMIT popupResizeMoved(mouse->globalPosition() - m_resizePress);
            Q_EMIT popupResizeFinished(true);
        }
        return false;
    }
    if (watched != m_modulePopup || !m_pointerWindow) return false;
    const auto global = mouse->globalPosition().toPoint();
    // Qt offers the active popup a copy of dock mouse events even when Wayland
    // selected the dock through the shadow. Decline it so Qt delivers the original.
    if (!m_modulePopup->mask().contains(m_modulePopup->mapFromGlobal(global))
        && m_lastInput.contains(m_pointerWindow->mapFromGlobal(global))) {
        event->ignore();
        return true;
    }
    return false;
}

void DockController::beginPopupResize(QQuickItem *grip, QPointF press)
{
    if (!grip || !m_modulePopup || grip->window() != m_modulePopup) return;
    m_resizePress = grip->mapToGlobal(press);
    m_resizingPopup = true;
}

void DockController::updatePopupSurface(QQuickItem *item, const QList<qreal> &corners, bool vertical, qreal border, bool blur)
{
    if (!item || !item->window() || item->size().isEmpty()) return;
    auto *window = item->window();
    const bool keyboardMenu = window->property("dockKeyboardMenu").toBool();
    if (!keyboardMenu && window->type() != Qt::Popup) return;
    if (m_modulePopup != window) {
        if (m_modulePopup) m_modulePopup->removeEventFilter(this);
        m_resizingPopup = false;
        m_modulePopup = window;
        window->installEventFilter(this);
    }
    const auto fill = DockGeometry::capsule(item->mapRectToScene(item->boundingRect()), corners, vertical);
    if (fill.isEmpty()) return;
    // The Wayland surface includes room for the shadow. Only the fill and
    // its outer border receive input, leaving the dock reachable underneath.
    QRegion input(fill.toFillPolygon().toPolygon());
    if (border > 0) {
        QPainterPathStroker stroke;
        stroke.setWidth(2 * border);
        stroke.setJoinStyle(Qt::RoundJoin);
        input |= QRegion(stroke.createStroke(fill).toFillPolygon().toPolygon(), Qt::WindingFill);
    }
    if (keyboardMenu && m_pointerWindow) {
        // Outside clicks dismiss the menu; dock icons remain directly reachable.
        const QPoint offset = window->mapFromGlobal(m_pointerWindow->mapToGlobal(QPoint()));
        input |= QRegion(QRect(QPoint(), window->size())) - m_lastInput.translated(offset);
    }
    if (window->mask() != input) window->setMask(input);
    auto *effects = window->findChild<BackgroundEffects *>(QString(), Qt::FindDirectChildrenOnly);
    if (!effects) effects = new BackgroundEffects(window, window);
    effects->configure({{"systemBlur", blur}});
    effects->setGeometry(fill);
}
