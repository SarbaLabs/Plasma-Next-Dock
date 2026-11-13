// SPDX-License-Identifier: GPL-2.0-or-later
#include "controller.h"
#include "icons.h"
#include "screenedge.h"
#include <LayerShellQt/Shell>
#include <LayerShellQt/Window>
#include <QCommandLineParser>
#include <QGuiApplication>
#include <QIcon>
#include <QQmlContext>
#include <QQmlEngine>
#include <QQmlError>
#include <QQuickView>
#include <QScreen>
#include <QTimer>
#include <QDebug>
#include <QLockFile>
#include <QStandardPaths>
#include <cmath>

// Older LayerShellQt derives the desired size directly from QWindow.
template<typename LayerWindow>
static void setDesiredSize(LayerWindow *window, const QSize &size)
{
    if constexpr (requires { window->setDesiredSize(size); }) window->setDesiredSize(size);
}

int main(int argc, char **argv)
{
    QGuiApplication app(argc, argv);
    initializeIconPaths();
    app.setApplicationName(QStringLiteral("plasma-next-dock"));
    app.setOrganizationName(QStringLiteral("SarbaLabs"));
    app.setDesktopFileName(QStringLiteral("org.sarbalabs.PlasmaNextDock"));
    QCommandLineParser parser;
    parser.setApplicationDescription(QStringLiteral("Plasma Next Dock — standalone Wayland prototype"));
    parser.addHelpOption();
    parser.addOptions({
        {"demo", "Use demonstration icons; do not launch applications."},
        {"smoke-test", "Run briefly and exit (for automated QML loading checks)."},
        {"edge", "Screen edge: bottom, top, left or right.", "edge", "bottom"},
        {"screen", "Output name from --list-screens.", "name"},
        {"list-screens", "List outputs and exit."},
        {"icon-size", "Resting icon size in logical pixels (24–96).", "pixels", "40"},
        {"zoom", "Magnification factor (1–2.5).", "factor", "1.5"},
        {"radius", "Capsule corner radius in logical pixels (0–96).", "pixels", "10"},
        {"glow", "Enable the bounded hover glow."},
        {"no-dodge", "Keep the dock visible even when a window overlaps it."},
        {"launcher", "Pinned desktop entry URL; repeat for multiple launchers.", "url"}
    });
    parser.process(app);
    if (parser.isSet("list-screens")) {
        for (auto *s : app.screens()) qInfo().noquote() << s->name() << s->geometry();
        return 0;
    }
    const bool smoke = parser.isSet("smoke-test");
    const bool demo = parser.isSet("demo");
    const bool wayland = app.platformName().startsWith("wayland");
    if (!wayland && !demo && !smoke) { qCritical("A Wayland session is required. Use --demo for a non-docking preview."); return 1; }
    const QStringList edgeNames = {"bottom", "top", "left", "right"};
    const int edgeIndex = edgeNames.indexOf(parser.value("edge"));
    bool iconOk, zoomOk, radiusOk;
    const int icon = parser.value("icon-size").toInt(&iconOk);
    const double zoom = parser.value("zoom").toDouble(&zoomOk);
    const double radius = parser.value("radius").toDouble(&radiusOk);
    if (edgeIndex < 0 || !iconOk || icon < 24 || icon > 96 || !zoomOk || !std::isfinite(zoom)
        || zoom < 1 || zoom > 2.5 || !radiusOk || !std::isfinite(radius) || radius < 0 || radius > 96) {
        qCritical("Invalid geometry options. See --help."); return 1;
    }
    QScreen *screen = app.primaryScreen();
    if (parser.isSet("screen")) {
        screen = nullptr;
        for (auto *candidate : app.screens()) if (candidate->name() == parser.value("screen")) screen = candidate;
    }
    if (!screen) { qCritical("Output not found. Use --list-screens."); return 1; }
    // Only one live dock per user in this prototype; demo instances are isolated.
    QLockFile lock(QStandardPaths::writableLocation(QStandardPaths::RuntimeLocation) + "/plasma-next-dock.lock");
    if (!demo && !smoke && !lock.tryLock(0)) { qCritical("Plasma Next Dock is already running."); return 1; }
    if (wayland) LayerShellQt::Shell::useLayerShell();
    QQuickView view;
    view.setTitle(QStringLiteral("Plasma Next Dock"));
    view.setScreen(screen);
    view.setColor(Qt::transparent);
    view.setFlags(Qt::FramelessWindowHint | Qt::WindowDoesNotAcceptFocus);
    view.setResizeMode(QQuickView::SizeViewToRootObject);
    const auto edge = static_cast<DockGeometry::Edge>(edgeIndex);
    LayerShellQt::Window *layer = nullptr;
    if (wayland) {
        layer = LayerShellQt::Window::get(&view);
        layer->setLayer(LayerShellQt::Window::LayerTop);
        layer->setKeyboardInteractivity(LayerShellQt::Window::KeyboardInteractivityNone);
        layer->setScope(QStringLiteral("plasma-next-dock"));
        layer->setExclusiveZone(-1); // No reserved work area; position against the physical output.
        const LayerShellQt::Window::Anchor anchors[] = {LayerShellQt::Window::AnchorBottom,
            LayerShellQt::Window::AnchorTop, LayerShellQt::Window::AnchorLeft, LayerShellQt::Window::AnchorRight};
        layer->setAnchors(anchors[edgeIndex]);
        layer->setCloseOnDismissed(true);
    }
    DockController controller(&view);
    controller.setDodgeEnabled(!demo && !parser.isSet("no-dodge"));
    std::unique_ptr<ScreenEdge> screenEdge;
    if (wayland) {
        screenEdge = std::make_unique<ScreenEdge>(&view, edge);
        controller.setEdgeAvailable(screenEdge->available());
        QObject::connect(screenEdge.get(), &ScreenEdge::availabilityChanged, &controller, &DockController::setEdgeAvailable);
        QObject::connect(&controller, &DockController::stateChanged, &view, [&] { screenEdge->setHidden(controller.hideRequested()); });
        if (!screenEdge->available()) qWarning("KDE screen-edge protocol unavailable; dodge is disabled to keep the dock reachable.");
    }
    auto position = [&] {
        const QRect rect = DockGeometry::surface(screen->geometry(), view.size(), edge);
        controller.setSurfaceOrigin(rect.topLeft());
        if (layer) setDesiredSize(layer, rect.size());
        view.setPosition(rect.topLeft()); // Qt popup coordinates; layer-shell controls actual placement.
    };
    view.rootContext()->setContextProperty("dockController", &controller);
    view.rootContext()->setContextProperty("dockOptions", QVariantMap{
        {"demo", demo}, {"edge", edgeIndex}, {"iconSize", icon}, {"zoom", zoom},
        {"radius", radius}, {"glow", parser.isSet("glow")}, {"launchers", parser.values("launcher")}});
    view.rootContext()->setContextProperty("outputSize", screen->size());
    QObject::connect(&view, &QWindow::widthChanged, &controller, position);
    QObject::connect(&view, &QWindow::heightChanged, &controller, position);
    QObject::connect(screen, &QScreen::geometryChanged, &controller, [&] {
        view.rootContext()->setContextProperty("outputSize", screen->size());
        position();
    });
    QObject::connect(&app, &QGuiApplication::screenRemoved, &view, [&](QScreen *removed) {
        if (removed == screen) { qWarning("Selected output removed; exiting safely. Restart on another output."); app.quit(); }
    });
    bool qmlFailed = false;
    QObject::connect(view.engine(), &QQmlEngine::warnings, &view, [&](const QList<QQmlError> &) { qmlFailed = true; });
    QObject::connect(view.engine(), &QQmlEngine::quit, &app, &QCoreApplication::quit);
    QObject::connect(view.engine(), &QQmlEngine::exit, &app, &QCoreApplication::exit);
    view.setSource(QUrl(QStringLiteral("qrc:/qml/Main.qml")));
    if (view.status() == QQuickView::Error || qmlFailed) { view.setSource(QUrl()); return 1; }
    position();
    view.show();
    if (smoke) QTimer::singleShot(700, &app, [&] {
        const QString capture = qEnvironmentVariable("PND_TEST_CAPTURE");
        if (!capture.isEmpty() && !view.grabWindow().save(capture)) qmlFailed = true;
        app.quit();
    });
    const int result = app.exec();
    view.hide();
    view.setSource(QUrl()); // Destroy QML while its controller is still alive.
    return smoke && qmlFailed ? 1 : result;
}
