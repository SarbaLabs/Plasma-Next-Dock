// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once
#include "geometry.h"
#include <QAbstractItemModel>
#include <QPointer>
#include <QQuickWindow>
#include <QQuickItem>
#include <QTimer>

class DockController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QAbstractItemModel *model READ model WRITE setModel NOTIFY modelChanged)
    Q_PROPERTY(bool pointerHovered READ pointerHovered NOTIFY pointerHoveredChanged)
    Q_PROPERTY(QPointF pointerPosition READ pointerPosition NOTIFY pointerPositionChanged)
    Q_PROPERTY(bool overlapping READ overlapping NOTIFY stateChanged)
    Q_PROPERTY(bool hideRequested READ hideRequested NOTIFY stateChanged)
    Q_PROPERTY(bool edgeAvailable READ edgeAvailable WRITE setEdgeAvailable NOTIFY stateChanged)
public:
    explicit DockController(QQuickWindow *window = nullptr, QObject *parent = nullptr);
    QAbstractItemModel *model() const { return m_model; }
    void setModel(QAbstractItemModel *model);
    bool pointerHovered() const { return m_pointerHovered; }
    QPointF pointerPosition() const { return m_pointerPosition; }
    Q_INVOKABLE void setPointerTarget(QQuickItem *target);
    bool overlapping() const { return m_overlapping; }
    bool hideRequested() const { return m_hideRequested; }
    bool edgeAvailable() const { return m_edgeAvailable; }
    void setEdgeAvailable(bool available);
    void setVisibility(DockGeometry::Visibility mode);
    void setSurfaceOrigin(QPoint origin);
    Q_INVOKABLE void setGeometry(QRectF capsule, qreal radius, QVariantList icons, int edge = DockGeometry::Bottom, const QList<qreal> &corners = {}, QRectF interactionBounds = {});
    Q_INVOKABLE QVariantMap capsuleDrawing(QSizeF size, const QList<qreal> &corners, bool vertical, qreal border) const;
    Q_INVOKABLE void setHovered(bool hovered);
    Q_INVOKABLE void setAttention(bool attention);
Q_SIGNALS:
    void pointerHoveredChanged();
    void pointerPositionChanged();
    void capsuleChanged(const QPainterPath &path);
    void modelChanged();
    void stateChanged();
private:
    bool eventFilter(QObject *watched, QEvent *event) override;
    void attachPointerWindow(QQuickWindow *window);
    void updatePointerHover();
    bool overlapsVisibleWindow() const;
    void scheduleEvaluation();
    void evaluate();
    QPointer<QQuickItem> m_pointerTarget;
    QPointer<QQuickWindow> m_pointerWindow;
    QList<QMetaObject::Connection> m_pointerConnections;
    QPointF m_pointerPosition;
    bool m_pointerPresent = false;
    bool m_pointerHovered = false;
    QPointer<QQuickWindow> m_window;
    QPointer<QAbstractItemModel> m_model;
    QList<QMetaObject::Connection> m_connections;
    QTimer m_leaveTimer;
    QPoint m_origin;
    QPainterPath m_shape;
    DockGeometry::Visibility m_visibility = DockGeometry::DodgeWindows;
    bool m_edgeAvailable = false;
    bool m_hovered = false;
    bool m_attention = false;
    bool m_overlapping = false;
    bool m_hideRequested = false;
    bool m_queued = false;
    QRegion m_lastInput;
};
