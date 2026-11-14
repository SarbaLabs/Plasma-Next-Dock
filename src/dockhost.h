// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once
#include "controller.h"
#include "backgroundeffects.h"
#include "screenedge.h"
#include "settings.h"
#include "layersurfaceposition.h"
#include <QQuickView>
class DockHost : public QObject
{
    Q_OBJECT
public:
    DockHost(DockSettings *settings, QScreen *screen, bool demo, bool wayland);
    ~DockHost() override;
    void update(bool settingsOpen);
    bool failed() const { return m_failed; }
    bool hasWarnings() const { return m_warnings; }
    QQuickView *view() { return &m_view; }
private:
    void position();
    DockSettings *m_settings;
    QScreen *m_screen;
    bool m_demo;
    DockGeometry::Edge m_edge;
    QQuickView m_view;
    DockController m_controller;
    BackgroundEffects m_backgroundEffects;
    LayerSurfacePosition *m_surfacePosition = nullptr;
    std::unique_ptr<ScreenEdge> m_screenEdge;
    bool m_failed = false;
    bool m_warnings = false;
};
