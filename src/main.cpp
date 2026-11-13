// SPDX-License-Identifier: GPL-2.0-or-later
#include "dockhost.h"
#include "icons.h"
#include <QCommandLineParser>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QScreen>
#include <QTimer>
#include <QLockFile>
#include <QStandardPaths>
#include <QQuickWindow>
#include <cmath>

int main(int argc, char **argv)
{
    QGuiApplication app(argc, argv);
    app.setQuitOnLastWindowClosed(false);
    initializeIconPaths();
    app.setApplicationName(QStringLiteral("plasma-next-dock"));
    app.setOrganizationName(QStringLiteral("SarbaLabs"));
    app.setDesktopFileName(QStringLiteral("org.sarbalabs.PlasmaNextDock"));
    QCommandLineParser parser;
    parser.setApplicationDescription(QStringLiteral("Plasma Next Dock — standalone Wayland dock"));
    parser.addHelpOption();
    parser.addOptions({
        {"demo", "Use demonstration icons and temporary settings."},
        {"smoke-test", "Run briefly with isolated settings and exit."},
        {"settings", "Open the configuration window at startup."},
        {"edge", "Screen edge: bottom, top, left or right.", "edge"},
        {"screen", "Output name from --list-screens.", "name"},
        {"list-screens", "List outputs and exit."},
        {"icon-size", "Resting icon size (24–96 logical pixels).", "pixels"},
        {"zoom", "Magnification factor (1–2.5).", "factor"},
        {"radius", "Corner radius (0–96 logical pixels).", "pixels"},
        {"spacing", "Distance from screen edge (0–128 logical pixels).", "pixels"},
        {"glow", "Enable hover glow."},
        {"no-dodge", "Keep the dock visible."},
        {"launcher", "Desktop entry URL; repeat for multiple launchers.", "url"}
    });
    parser.process(app);
    if (parser.isSet("list-screens")) {
        for (auto *s : app.screens()) qInfo().noquote() << s->name() << s->geometry();
        return 0;
    }
    const bool smoke = parser.isSet("smoke-test"), demo = parser.isSet("demo");
    const bool wayland = app.platformName().startsWith("wayland");
    if (!wayland && !demo && !smoke) { qCritical("A Wayland session is required. Use --demo for a preview."); return 1; }
    DockSettings settings(QStandardPaths::writableLocation(QStandardPaths::ConfigLocation) + "/plasma-next-dock.ini", !demo && !smoke);
    QVariantMap overrides;
    const QStringList edgeNames = {"bottom", "top", "left", "right"};
    if (parser.isSet("edge")) {
        const int e = edgeNames.indexOf(parser.value("edge"));
        if (e < 0) { qCritical("Invalid edge."); return 1; }
        overrides["edge"] = e;
    }
    for (const auto &name : {"icon-size", "zoom", "radius", "spacing"}) if (parser.isSet(name)) {
        bool ok; const double value = parser.value(name).toDouble(&ok);
        const QString key = QString::fromLatin1(name) == "icon-size" ? "iconSize" : name;
        QVariantMap probe{{key, value}};
        if (!ok || !std::isfinite(value) || DockSettings::normalized(probe)[key].toDouble() != value) {
            qCritical("Invalid geometry option."); return 1;
        }
        overrides[key] = value;
    }
    if (parser.isSet("screen")) overrides["screen"] = parser.value("screen");
    if (parser.isSet("glow")) overrides["glow"] = true;
    if (parser.isSet("no-dodge")) overrides["dodge"] = false;
    if (parser.isSet("launcher")) overrides["launchers"] = parser.values("launcher");
    settings.overrideSession(overrides);
    QLockFile lock(QStandardPaths::writableLocation(QStandardPaths::RuntimeLocation) + "/plasma-next-dock.lock");
    if (!demo && !smoke && !lock.tryLock(0)) { qCritical("Dock already running. Use its right-click Configure menu."); return 1; }
    QQmlApplicationEngine configEngine;
    configEngine.rootContext()->setContextProperty("dockSettings", &settings);
    auto outputs = [&] {
        QStringList names{QString()};
        for (auto *s : app.screens()) names << s->name();
        configEngine.rootContext()->setContextProperty("outputNames", names);
    };
    outputs();
    QObject::connect(&app, &QGuiApplication::screenAdded, &configEngine, outputs);
    QObject::connect(&app, &QGuiApplication::screenRemoved, &configEngine, outputs);
    bool configFailed = false;
    QObject::connect(&configEngine, &QQmlEngine::warnings, &app, [&] { configFailed = true; });
    QObject::connect(&configEngine, &QQmlEngine::quit, &app, &QCoreApplication::quit);
    configEngine.load(QUrl(QStringLiteral("qrc:/qml/Settings.qml")));
    if (configEngine.rootObjects().isEmpty() || (smoke && configFailed)) return 1;
    auto *configWindow = qobject_cast<QQuickWindow *>(configEngine.rootObjects().first());
    std::unique_ptr<DockHost> host;
    QScreen *selected = nullptr;
    int edge = -1;
    auto refresh = [&] {
        QScreen *screen = app.primaryScreen();
        const QString wanted = settings.values()["screen"].toString();
        for (auto *s : app.screens()) if (s->name() == wanted) screen = s;
        if (!screen) { app.quit(); return; }
        const int nextEdge = settings.values()["edge"].toInt();
        if (!host || screen != selected || nextEdge != edge) {
            // Settings changes, not dodge: retire the old role before creating a new one.
            host.reset(); selected = screen; edge = nextEdge;
            host = std::make_unique<DockHost>(&settings, screen, demo, wayland);
        }
        host->update(configWindow->isVisible());
        if (host->failed()) app.exit(1);
    };
    refresh();
    if (!host || host->failed()) return 1;
    QObject::connect(&settings, &DockSettings::changed, &app, refresh, Qt::QueuedConnection);
    QObject::connect(configWindow, &QWindow::visibleChanged, &app, refresh, Qt::QueuedConnection);
    QObject::connect(&app, &QGuiApplication::primaryScreenChanged, &app, refresh, Qt::QueuedConnection);
    QObject::connect(&app, &QGuiApplication::screenAdded, &app, refresh, Qt::QueuedConnection);
    QObject::connect(&app, &QGuiApplication::screenRemoved, &app, [&](QScreen *removed) {
        if (removed == selected) { host.reset(); selected = nullptr; QTimer::singleShot(0, &app, refresh); }
    });
    QObject::connect(&settings, &DockSettings::configureRequested, configWindow, [&] {
        QMetaObject::invokeMethod(configWindow, "openSettings");
        configWindow->requestActivate();
    });
    if (parser.isSet("settings")) settings.configure();
    if (smoke) QTimer::singleShot(700, &app, [&] {
        const QString configCapture = qEnvironmentVariable("PND_TEST_CAPTURE_SETTINGS");
        if (!configCapture.isEmpty() && !configWindow->grabWindow().save(configCapture)) configFailed = true;
        const QString capture = qEnvironmentVariable("PND_TEST_CAPTURE");
        if (!capture.isEmpty() && !host->view()->grabWindow().save(capture)) configFailed = true;
        app.quit();
    });
    const int result = app.exec();
    const bool failed = configFailed || (host && (host->failed() || host->hasWarnings()));
    host.reset();
    return smoke && failed ? 1 : result;
}
