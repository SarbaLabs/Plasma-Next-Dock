// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once
#include "controller.h"
#include "backgroundeffects.h"
#include "screenedge.h"
#include "settings.h"
#include "modules/taskrows.h"
#include "layersurfaceposition.h"
#include <QQuickView>
class DockHost : public QObject
{
    Q_OBJECT
public:
    DockHost(DockSettings *settings, QScreen *screen, bool demo, bool wayland, const ModuleCatalog &catalog);
    ~DockHost() override;
    void update(bool settingsOpen);
    Q_INVOKABLE QQuickItem *keyboardMenuSurface();
    bool beginKeyboard();
    bool hasApplicationsMenu() const { return m_modules.loaded(QStringLiteral("org.sarbalabs.appmenu")); }
    bool keyboardActive() const;
    void endKeyboard();
    QScreen *output() const { return m_screen; }
    DockGeometry::Edge edge() const { return m_edge; }
    bool failed() const { return m_failed; }
    bool hasWarnings() const { return m_warnings; }
    QQuickView *view() { return &m_view; }
private Q_SLOTS:
    void position();
    void syncKeyboard();
private:
    void updateReservation();
    std::unique_ptr<QQuickWindow> m_reservation;
    DockSettings *m_settings;
    QScreen *m_screen;
    QVariantMap m_options;
    bool m_demo;
    DockGeometry::Edge m_edge;
    ModuleManager m_modules;
    TaskRows m_taskRows;
    QQuickView m_view;
    std::unique_ptr<QQuickWindow> m_menuSurface;
    DockController m_controller;
    BackgroundEffects m_backgroundEffects;
    LayerSurfacePosition *m_surfacePosition = nullptr;
    std::unique_ptr<ScreenEdge> m_screenEdge;
    bool m_failed = false;
    bool m_warnings = false;
};
