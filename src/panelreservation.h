// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once
#include "geometry.h"
#include <KDirWatch>
#include <QObject>
#include <QTimer>

class QScreen;

// Plasma panels reserve space before the dock's layer-shell reservation.
class PanelReservation : public QObject
{
    Q_OBJECT
public:
    PanelReservation(QScreen *screen, DockGeometry::Edge edge);
    int thickness() const { return m_thickness; }
Q_SIGNALS:
    void changed();
private:
    void schedule();
    void query();
    void setThickness(int value);
    QScreen *m_screen;
    DockGeometry::Edge m_edge;
    KDirWatch m_files;
    QTimer m_delay;
    int m_thickness = 0;
    unsigned m_revision = 0;
    int m_startupRetries = 0;
};
