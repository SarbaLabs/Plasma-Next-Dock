// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once
#include <QObject>
#include <QPointer>
#include <QQuickItem>
#include <QWindow>
#include <optional>

// Keep Qt's Wayland positioner compatibility properties in one small adapter.
class PopupAnchor : public QObject
{
    Q_OBJECT
public:
    explicit PopupAnchor(QObject *parent = nullptr);
    Q_INVOKABLE void prepare(QQuickItem *item, QPointF point, int edge, bool slideAcrossEdge = true, bool animate = false);
    Q_INVOKABLE void prepareContextMenu(QQuickItem *anchor, int edge);
protected:
    bool eventFilter(QObject *object, QEvent *event) override;
private:
    void setAnchor(QQuickItem *item, QPointF point, Qt::Edges gravity, std::optional<uint> constraints, bool animate);
    void attach(QWindow *popup);
    void transientParentChanged();
    void apply(QWindow *popup);
    QPointer<QWindow> m_parentWindow;
    QPointer<QWindow> m_popup;
    QRect m_anchor;
    Qt::Edges m_gravity;
    bool m_pending = false;
    bool m_animate = false;
    std::optional<uint> m_constraints;
};
