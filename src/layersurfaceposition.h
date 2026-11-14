// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once
#include <QObject>
#include <QPointer>
#include <QPoint>
#include <QWindow>

// Publish the known layer-shell origin to Qt's client-side coordinate mapping.
// The compositor still positions the surface using its layer-shell anchors.
class LayerSurfacePosition : public QObject
{
public:
    explicit LayerSurfacePosition(QWindow *window);
    void setOrigin(QPoint origin);
protected:
    bool eventFilter(QObject *object, QEvent *event) override;
private:
    void schedule();
    void apply();
    QPointer<QWindow> m_window;
    QPoint m_origin;
    bool m_pending = false;
    bool m_applying = false;
};
