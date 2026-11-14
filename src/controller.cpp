// SPDX-License-Identifier: GPL-2.0-or-later
#include "controller.h"

DockController::DockController(QQuickWindow *window, QObject *parent)
    : QObject(parent), m_window(window)
{
    m_leaveTimer.setSingleShot(true);
    m_leaveTimer.setInterval(180);
    connect(&m_leaveTimer, &QTimer::timeout, this, &DockController::evaluate);
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
void DockController::setGeometry(QRectF rect, qreal radius, QVariantList icons, int edge)
{
    QList<QRectF> iconRects;
    for (const auto &icon : icons) iconRects << icon.toRectF();
    if (m_window) {
        const QRegion input = DockGeometry::inputRegion(rect, radius, iconRects, QRect(QPoint(), m_window->size()), static_cast<DockGeometry::Edge>(edge));
        // Under Qt Wayland this is the surface input region, not a rendering clip.
        if (input != m_lastInput) {
            m_lastInput = input;
            m_window->setMask(input);
        }
    }
    if (rect == m_capsule && radius == m_radius) return;
    m_capsule = rect;
    m_radius = radius;
    Q_EMIT capsuleChanged(rect, radius);
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
void DockController::setDodgeEnabled(bool value)
{
    m_dodgeEnabled = value;
    evaluate();
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
        const auto globalCapsule = m_capsule.translated(m_origin);
        // An ungrouped TasksModel, already filtered by desktop/activity, is required.
        if (geometryRole >= 0 && windowRole >= 0 && minimizedRole >= 0) {
            for (int row = 0; row < m_model->rowCount(); ++row) {
                const auto index = m_model->index(row, 0);
                if (!index.data(windowRole).toBool() || index.data(minimizedRole).toBool()) continue;
                if (DockGeometry::overlaps(index.data(geometryRole).toRectF(), globalCapsule, m_radius)) {
                    overlap = true;
                    break;
                }
            }
        }
    }
    const bool hide = overlap && m_dodgeEnabled && m_edgeAvailable && !m_hovered && !m_leaveTimer.isActive();
    if (overlap == m_overlapping && hide == m_hideRequested) return;
    m_overlapping = overlap;
    m_hideRequested = hide;
    Q_EMIT stateChanged();
}
