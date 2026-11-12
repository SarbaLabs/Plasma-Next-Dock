// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once
#include <QObject>
#include <QWindow>
#include <memory>
#include "geometry.h"
class ScreenEdge : public QObject
{
    Q_OBJECT
public:
    ScreenEdge(QWindow *window, DockGeometry::Edge edge);
    ~ScreenEdge() override;
    void setHidden(bool hidden);
    bool available() const;
Q_SIGNALS:
    void availabilityChanged(bool available);
protected:
    bool eventFilter(QObject *object, QEvent *event) override;
private:
    void synchronize();
    class Private;
    std::unique_ptr<Private> d;
};
