// SPDX-License-Identifier: GPL-2.0-or-later
#include "launcherresolver.h"
#include "dockhost.h"
#include "statussupport.h"
#include "popupanchor.h"
#include "applicationmenubackend.h"
#include "menutarget.h"
#include "windowpreviewmodel.h"
#include <KLocalizedQmlContext>
#include <LayerShellQt/Window>
#include <QQmlContext>
#include <QQmlEngine>
#include <QQmlError>
#include <QGuiApplication>
#include <QScreen>

template<typename T> static void desiredSize(T *window, QSize size)
{
    if constexpr (requires { window->setDesiredSize(size); }) window->setDesiredSize(size);
}
template<typename T> static void selectOutput(T *window, QScreen *screen)
{
    if constexpr (requires { window->setScreen(screen); }) window->setScreen(screen);
}
static LayerShellQt::Window::Anchor edgeAnchor(DockGeometry::Edge edge)
{
    using Layer = LayerShellQt::Window;
    constexpr Layer::Anchor anchors[] = {Layer::AnchorBottom, Layer::AnchorTop, Layer::AnchorLeft, Layer::AnchorRight};
    return anchors[edge];
}
DockHost::DockHost(DockSettings *settings, QScreen *screen, bool demo, bool wayland)
    : m_settings(settings), m_screen(screen), m_demo(demo),
      m_edge(static_cast<DockGeometry::Edge>(settings->values()["edge"].toInt())), m_controller(&m_view), m_backgroundEffects(&m_view)
{
    connect(&m_controller, &DockController::capsuleChanged, &m_backgroundEffects, &BackgroundEffects::setGeometry);
    m_view.setTitle(QStringLiteral("Plasma Next Dock"));
    m_view.setScreen(screen);
    m_view.setColor(Qt::transparent);
    m_view.setFlags(Qt::FramelessWindowHint | Qt::WindowDoesNotAcceptFocus);
    m_view.setResizeMode(QQuickView::SizeViewToRootObject);
    if (wayland) {
        m_surfacePosition = new LayerSurfacePosition(&m_view);
        // Select layer-shell for this window only; settings retain normal xdg-shell.
        auto *layer = LayerShellQt::Window::get(&m_view);
        selectOutput(layer, screen);
        layer->setLayer(LayerShellQt::Window::LayerTop);
        layer->setKeyboardInteractivity(LayerShellQt::Window::KeyboardInteractivityNone);
        layer->setScope(QStringLiteral("plasma-next-dock"));
        layer->setExclusiveZone(-1);
        layer->setCloseOnDismissed(true);
        m_screenEdge = std::make_unique<ScreenEdge>(&m_view, m_edge);
        m_controller.setEdgeAvailable(m_screenEdge->available());
        connect(m_screenEdge.get(), &ScreenEdge::availabilityChanged, &m_controller, &DockController::setEdgeAvailable);
        connect(&m_controller, &DockController::stateChanged, this, [this] { m_screenEdge->setHidden(m_controller.hideRequested()); });
    }
    auto *localized = new KLocalizedQmlContext(m_view.engine());
    localized->setTranslationDomain(QStringLiteral("plasma-next-dock"));
    m_view.engine()->rootContext()->setContextObject(localized);
    QQmlEngine::setContextForObject(localized, m_view.engine()->rootContext());
    m_view.rootContext()->setContextProperty("statusSupport", new StatusSupport(this));
    m_view.rootContext()->setContextProperty("applicationMenus", new ApplicationMenuBackend(this));
    m_view.rootContext()->setContextProperty("menuTarget", new MenuTarget(this));
    m_view.rootContext()->setContextProperty("dropTarget", new MenuTarget(this));
    m_view.rootContext()->setContextProperty("launcherResolver", new LauncherResolver(this));
    m_view.rootContext()->setContextProperty("windowPreviews", new WindowPreviewModel(this));
    m_view.rootContext()->setContextProperty("dockMenuAnchor", new PopupAnchor(this));
    m_view.rootContext()->setContextProperty("dockController", &m_controller);
    m_view.rootContext()->setContextProperty("dockSettings", settings);
    m_view.rootContext()->setContextProperty("outputSize", screen->size());
    m_view.rootContext()->setContextProperty("outputGeometry", screen->geometry());
    update(false);
    connect(&m_view, &QWindow::widthChanged, this, &DockHost::position);
    connect(&m_view, &QWindow::heightChanged, this, &DockHost::position);
    connect(screen, &QScreen::geometryChanged, this, [this] {
        m_view.rootContext()->setContextProperty("outputSize", m_screen->size());
        m_view.rootContext()->setContextProperty("outputGeometry", m_screen->geometry()); position();
    });
    connect(m_view.engine(), &QQmlEngine::warnings, this, [this](const QList<QQmlError> &) { m_warnings = true; });
    connect(m_view.engine(), &QQmlEngine::quit, qApp, &QCoreApplication::quit);
    connect(m_view.engine(), &QQmlEngine::exit, qApp, &QCoreApplication::exit);
    m_view.setSource(QUrl(QStringLiteral("qrc:/qml/Main.qml")));
    m_failed |= m_view.status() == QQuickView::Error;
    if (m_view.rootObject())
        connect(m_view.rootObject(), SIGNAL(reservedThicknessChanged()), this, SLOT(position()));
    position();
    if (!m_failed) m_view.show();
}
DockHost::~DockHost()
{
    m_view.hide();
    m_view.setSource(QUrl()); // QML must die before the model/controller.
}
void DockHost::update(bool settingsOpen)
{
    auto options = m_settings->values(); options["demo"] = m_demo;
    m_view.rootContext()->setContextProperty("dockOptions", options);
    m_backgroundEffects.configure(options);
    if (m_screenEdge) m_screenEdge->setAnimated(options["revealAnimation"].toBool());
    const auto mode = static_cast<DockGeometry::Visibility>(options["visibilityMode"].toInt());
    m_controller.setVisibility(m_demo || settingsOpen ? DockGeometry::WindowsGoBelow : mode);
    position();
}
void DockHost::position()
{
    const auto alignment = static_cast<DockGeometry::Alignment>(m_settings->values()["dockAlignment"].toInt());
    const QRect rect = DockGeometry::surface(m_screen->geometry(), m_view.size(), m_edge, alignment);
    m_controller.setSurfaceOrigin(rect.topLeft());
    if (m_surfacePosition) {
        using Layer = LayerShellQt::Window;
        auto *layer = Layer::get(&m_view);
        Layer::Anchors anchors = edgeAnchor(m_edge);
        if (alignment == DockGeometry::Start) anchors |= m_edge < DockGeometry::Left ? Layer::AnchorLeft : Layer::AnchorTop;
        if (alignment == DockGeometry::End) anchors |= m_edge < DockGeometry::Left ? Layer::AnchorRight : Layer::AnchorBottom;
        if (layer->anchors() != anchors) {
            layer->setAnchors(anchors);
            m_view.update();
        }
        desiredSize(layer, rect.size());
        updateReservation();
    }
    if (m_surfacePosition) m_surfacePosition->setOrigin(rect.topLeft());
    else m_view.setPosition(rect.topLeft());
}

void DockHost::updateReservation()
{
    if (m_demo || m_settings->values()["visibilityMode"].toInt() != DockGeometry::AlwaysVisible || !m_view.rootObject()) {
        m_reservation.reset();
        return;
    }
    // Keep the visual surface on the physical output edge even when other
    // panels reserve space. A separate single-edge surface has an unambiguous
    // exclusive edge, including on earlier layer-shell protocol versions.
    using Layer = LayerShellQt::Window;
    if (!m_reservation) {
        m_reservation = std::make_unique<QQuickWindow>();
        m_reservation->setScreen(m_screen);
        m_reservation->setFlags(Qt::FramelessWindowHint | Qt::WindowDoesNotAcceptFocus | Qt::WindowTransparentForInput);
        m_reservation->setColor(Qt::transparent);
        auto *layer = Layer::get(m_reservation.get());
        selectOutput(layer, m_screen);
        layer->setLayer(Layer::LayerBottom);
        layer->setAnchors(edgeAnchor(m_edge));
        layer->setScope(QStringLiteral("plasma-next-dock-reservation"));
        layer->setKeyboardInteractivity(Layer::KeyboardInteractivityNone);
    }
    auto *layer = Layer::get(m_reservation.get());
    const QSize size = m_edge < DockGeometry::Left ? QSize(m_screen->size().width(), 1) : QSize(1, m_screen->size().height());
    m_reservation->resize(size);
    desiredSize(layer, size);
    const int thickness = m_view.rootObject()->property("reservedThickness").toInt();
    if (layer->exclusionZone() != thickness) {
        layer->setExclusiveZone(thickness);
        m_reservation->update();
    }
    m_reservation->show();
}
