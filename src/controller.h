// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once
#include "geometry.h"
#include <QAbstractItemModel>
#include <QPointer>
#include <QQuickWindow>
#include <QTimer>

class DockController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QAbstractItemModel *model READ model WRITE setModel NOTIFY modelChanged)
    Q_PROPERTY(bool overlapping READ overlapping NOTIFY stateChanged)
    Q_PROPERTY(bool hideRequested READ hideRequested NOTIFY stateChanged)
    Q_PROPERTY(bool edgeAvailable READ edgeAvailable WRITE setEdgeAvailable NOTIFY stateChanged)
public:
    explicit DockController(QQuickWindow *window = nullptr, QObject *parent = nullptr);
    QAbstractItemModel *model() const { return m_model; }
    void setModel(QAbstractItemModel *model);
    bool overlapping() const { return m_overlapping; }
    bool hideRequested() const { return m_hideRequested; }
    bool edgeAvailable() const { return m_edgeAvailable; }
    void setEdgeAvailable(bool available);
    void setDodgeEnabled(bool enabled);
    void setSurfaceOrigin(QPoint origin);
    Q_INVOKABLE void setGeometry(QRectF capsule, qreal radius, QVariantList icons, int edge = DockGeometry::Bottom);
    Q_INVOKABLE void setHovered(bool hovered);
    Q_INVOKABLE void evaluate();
    Q_INVOKABLE void setAttention(bool attention);
Q_SIGNALS:
    void capsuleChanged(QRectF capsule, qreal radius);
    void modelChanged();
    void stateChanged();
private:
    void scheduleEvaluation();
    QPointer<QQuickWindow> m_window;
    QPointer<QAbstractItemModel> m_model;
    QList<QMetaObject::Connection> m_connections;
    QTimer m_leaveTimer;
    QPoint m_origin;
    QRectF m_capsule;
    qreal m_radius = 0;
    bool m_dodgeEnabled = true;
    bool m_edgeAvailable = false;
    bool m_hovered = false;
    bool m_attention = false;
    bool m_overlapping = false;
    bool m_hideRequested = false;
    bool m_queued = false;
    QRegion m_lastInput;
};
