// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once
#include <QObject>
#include <QPointer>
#include <QQuickItem>
#include <QWindow>

// Keep Qt's Wayland positioner compatibility properties in one small adapter.
class PopupAnchor : public QObject
{
    Q_OBJECT
public:
    explicit PopupAnchor(QObject *parent = nullptr);
    Q_INVOKABLE void prepare(QQuickItem *item, QPointF point, int edge, bool slideAcrossEdge = true);
protected:
    bool eventFilter(QObject *object, QEvent *event) override;
private:
    void apply(QWindow *popup);
    QPointer<QWindow> m_parentWindow;
    QPointer<QWindow> m_popup;
    QRect m_anchor;
    Qt::Edges m_gravity;
    uint m_constraints = 0;
};
