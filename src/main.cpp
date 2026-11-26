// SPDX-License-Identifier: GPL-2.0-or-later
#include "launcherresolver.h"
#include "launcherrelay.h"
#include "dockhost.h"
#include <QIcon>
#include <QJsonDocument>
#include <QTextStream>
#include "dockprofiles.h"
#include <map>
#include "icons.h"
#include <QCommandLineParser>
#include <QApplication>
#include <KLocalizedString>
#include <KLocalizedQmlContext>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QScreen>
#include <QAction>
#include <KGlobalAccel>
#include <QDir>
#include <QTimer>
#include <QLockFile>
#include <QStandardPaths>
#include <QQuickWindow>
#include <cmath>

int main(int argc, char **argv)
{
    QCoreApplication::setApplicationVersion(QStringLiteral(DOCK_VERSION));
    // A version query also works from a terminal outside the graphical session.
    if (argc == 2 && (qstrcmp(argv[1], "--version") == 0 || qstrcmp(argv[1], "-v") == 0)) {
        QCoreApplication app(argc, argv);
        app.setApplicationName(QStringLiteral("plasma-next-dock"));
        QCommandLineParser().showVersion();
    }
    // Layer-shell frame callbacks can arrive more slowly than the output refresh.
    // Keep Qt Quick transitions on elapsed time as auxiliary windows come and go.
    if (!qEnvironmentVariableIsSet("QSG_USE_SIMPLE_ANIMATION_DRIVER"))
        qputenv("QSG_USE_SIMPLE_ANIMATION_DRIVER", "1");
    QApplication app(argc, argv);
    KLocalizedString::setApplicationDomain("plasma-next-dock");
    app.setQuitOnLastWindowClosed(false);
    initializeIconPaths();
    app.setApplicationName(QStringLiteral("plasma-next-dock"));
    app.setOrganizationName(QStringLiteral("SarbaLabs"));
    app.setDesktopFileName(QStringLiteral("org.sarbalabs.PlasmaNextDock"));
    app.setWindowIcon(QIcon::fromTheme(app.desktopFileName(), QIcon(QStringLiteral(":/icons/org.sarbalabs.PlasmaNextDock.svg"))));
    QCommandLineParser parser;
    parser.setApplicationDescription(QStringLiteral("Plasma Next Dock — standalone Wayland dock"));
    parser.addHelpOption();
    parser.addVersionOption();
    parser.addOptions({
        {"autostart", "Start at login if the dock is not already running."},
        {"demo", "Use demonstration icons and temporary settings."},
        {"smoke-test", "Run briefly with isolated settings and exit."},
        {"settings", "Open the configuration window at startup."},
        {"edge", "Screen edge: bottom, top, left or right.", "edge"},
        {"screen", "Output name from --list-screens.", "name"},
        {"list-modules", "List discovered module metadata as JSON and exit."},
        {"inspect-module", "Load one module with default settings, print its initial entries as JSON and exit.", "id"},
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
    auto roots = QStandardPaths::standardLocations(QStandardPaths::GenericDataLocation);
    // Also honor an installation prefix outside XDG_DATA_DIRS (e.g. staged installs).
    const QDir desktopEntryDir(QFileInfo(app.applicationDirPath() + "/" + DOCK_AUTOSTART_ENTRY).absolutePath());
    roots.append(QDir::cleanPath(desktopEntryDir.absoluteFilePath("..")));
    const auto catalog = (smoke || demo) ? ModuleCatalog{}
        : discoverModules(roots);
    if (parser.isSet("list-modules") || parser.isSet("inspect-module")) {
        QVariantList result;
        if (parser.isSet("inspect-module")) {
            const auto id = parser.value("inspect-module");
            ModuleManager manager(catalog);
            manager.configure({id}, {});
            if (!manager.loaded(id)) return 1;
            result = manager.entries();
        } else {
            for (const auto &package : catalog) result.append(package.metadata);
        }
        QTextStream(stdout) << QJsonDocument::fromVariant(result).toJson();
        return 0;
    }
    const bool wayland = app.platformName().startsWith("wayland");
    if (!wayland && !demo && !smoke) { qCritical("A Wayland session is required. Use --demo for a preview."); return 1; }
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
    QLockFile lock(QStandardPaths::writableLocation(QStandardPaths::RuntimeLocation) + "/plasma-next-dock.lock");
    if (!demo && !smoke && !lock.tryLock(0)) {
        if (lock.error() == QLockFile::LockFailedError && parser.isSet("autostart")) return 0;
        qCritical("Could not acquire the dock instance lock. If already running, use its right-click Configure menu.");
        return 1;
    }
    DockProfiles profiles(QStandardPaths::writableLocation(QStandardPaths::ConfigLocation) + "/plasma-next-dock.ini",
                          !demo && !smoke, QDir::cleanPath(app.applicationDirPath() + "/" + DOCK_AUTOSTART_ENTRY));
    profiles.current()->overrideSession(overrides);
    QQmlApplicationEngine configEngine;
    auto *configTranslations = new KLocalizedQmlContext(&configEngine);
    configTranslations->setTranslationDomain(QStringLiteral("plasma-next-dock"));
    configEngine.rootContext()->setContextObject(configTranslations);
    QQmlEngine::setContextForObject(configTranslations, configEngine.rootContext());
    configEngine.rootContext()->setContextProperty("dockSettings", profiles.current());
    configEngine.rootContext()->setContextProperty("dockProfiles", &profiles);
    QVariantMap moduleCatalog;
    for (auto it = catalog.cbegin(); it != catalog.cend(); ++it) moduleCatalog.insert(it.key(), it->metadata);
    configEngine.rootContext()->setContextProperty("moduleCatalog", moduleCatalog);
    configEngine.rootContext()->setContextProperty("launcherResolver", new LauncherResolver(&configEngine));
    auto outputs = [&] {
        QStringList names;
        QVariantMap descriptions;
        for (const auto *screen : app.screens()) {
            const QString connector = screen->name();
            names << connector;
            const QString make = screen->manufacturer().simplified();
            QString model = screen->model().simplified();
            if (model.compare(connector, Qt::CaseInsensitive) == 0) model.clear();
            if (!make.isEmpty() && !model.startsWith(make, Qt::CaseInsensitive))
                model = model.isEmpty() ? make : make + " " + model;
            descriptions.insert(connector, model);
        }
        configEngine.rootContext()->setContextProperty("outputDescriptions", descriptions);
        const QString primary = app.primaryScreen() ? app.primaryScreen()->name() : QString();
        configEngine.rootContext()->setContextProperty("primaryOutput", primary);
        profiles.setOutputs(names, primary);
        configEngine.rootContext()->setContextProperty("outputNames", QStringList{QString()} + names);
    };
    outputs();
    bool configFailed = false;
    QObject::connect(&configEngine, &QQmlEngine::warnings, &app, [&] { configFailed = true; });
    QObject::connect(&configEngine, &QQmlEngine::quit, &app, &QCoreApplication::quit);
    configEngine.load(QUrl(QStringLiteral("qrc:/qml/Settings.qml")));
    if (configEngine.rootObjects().isEmpty() || (smoke && configFailed)) return 1;
    auto *configWindow = qobject_cast<QQuickWindow *>(configEngine.rootObjects().first());
    std::map<DockSettings *, std::unique_ptr<DockHost>> hosts;
    QObject connections;
    LauncherRelay launcherRelay;
    auto refresh = [&] {
        QStringList launcherOutputs;
        std::erase_if(hosts, [&](const auto &entry) { return !profiles.profiles().contains(entry.first); });
        for (auto *profile : profiles.profiles()) {
            const QString output = profiles.assignedOutput(profile);
            QScreen *screen = nullptr;
            for (auto *candidate : app.screens())
                if (candidate->name() == output && !output.isEmpty()) screen = candidate;
            // Qt's offscreen platform can have an unnamed primary output.
            if (!wayland && !screen) screen = app.primaryScreen();
            if (!screen) { hosts.erase(profile); continue; }
            const int edge = profile->values()["edge"].toInt();
            auto &host = hosts[profile];
            if (!host || screen != host->output() || edge != host->edge()) {
                host.reset();
                host = std::make_unique<DockHost>(profile, screen, demo, wayland, catalog);
            }
            host->update(configWindow->isVisible() && profiles.current() == profile);
            if (host->hasApplicationsMenu()) launcherOutputs.append(output);
            if (host->failed()) { configFailed = true; app.exit(1); }
        }
        launcherRelay.setOutputs(launcherOutputs);
        const auto selected = hosts.find(profiles.current());
        auto *root = selected == hosts.end() ? nullptr : selected->second->view()->rootObject();
        configWindow->setProperty("selectedTasks", root ? root->property("presentationTasks") : QVariant::fromValue<QObject *>(nullptr));
    };
    auto topologyChanged = [&] { outputs(); refresh(); };
    QObject::connect(&app, &QGuiApplication::screenAdded, &connections, topologyChanged);
    QObject::connect(&app, &QGuiApplication::primaryScreenChanged, &connections, topologyChanged);
    QObject::connect(&app, &QGuiApplication::screenRemoved, &connections, [&](QScreen *removed) {
        std::erase_if(hosts, [removed](const auto &entry) { return entry.second->output() == removed; });
        QTimer::singleShot(0, &connections, topologyChanged);
    });
    QObject::connect(&profiles, &DockProfiles::profileChanged, &connections, refresh, Qt::QueuedConnection);
    QObject::connect(&profiles, &DockProfiles::listChanged, &connections, refresh);
    QObject::connect(configWindow, &QWindow::visibleChanged, &connections, refresh, Qt::QueuedConnection);
    QObject::connect(&profiles, &DockProfiles::selectionChanged, &connections, [&] {
        configEngine.rootContext()->setContextProperty("dockSettings", profiles.current());
        if (configWindow->isVisible()) QMetaObject::invokeMethod(configWindow, "openSettings");
        refresh();
    });
    QObject::connect(&profiles, &DockProfiles::openRequested, &connections, [&] {
        QMetaObject::invokeMethod(configWindow, "openSettings");
        configWindow->requestActivate();
    });
    refresh();
    for (const auto &entry : hosts) if (entry.second->failed()) return 1;
    if (configFailed && smoke) return 1;
    QAction focusDock(i18n("Focus Plasma Next Dock"));
    if (wayland && !demo && !smoke) {
        QObject::connect(&launcherRelay, &LauncherRelay::requested, &connections, [&](const QString &output) {
            for (const auto &entry : hosts) {
                if (entry.second->output()->name() != output)
                    QMetaObject::invokeMethod(entry.second->view()->rootObject(), "dismissKeyboardMenu");
            }
            for (auto *profile : profiles.profiles()) {
                const auto it = hosts.find(profile);
                if (it == hosts.end() || it->second->output()->name() != output || !it->second->hasApplicationsMenu()) continue;
                QMetaObject::invokeMethod(it->second->view()->rootObject(), "toggleApplicationsMenu");
                break;
            }
        });
        launcherRelay.start();
        focusDock.setObjectName(QStringLiteral("focus-dock"));
        focusDock.setProperty("componentDisplayName", QStringLiteral("Plasma Next Dock"));
        const QKeySequence shortcut(Qt::META | Qt::ALT | Qt::Key_Space);
        KGlobalAccel::setGlobalShortcut(&focusDock, shortcut);
        QObject::connect(&focusDock, &QAction::triggered, &connections, [&] {
            const auto &list = profiles.profiles();
            int first = profiles.selectedIndex();
            for (int i = 0; i < list.size(); ++i) {
                const auto it = hosts.find(list[i]);
                if (it != hosts.end() && it->second->keyboardActive()) {
                    it->second->endKeyboard();
                    first = (i + 1) % list.size();
                    break;
                }
            }
            for (int i = 0; i < list.size(); ++i) {
                const auto it = hosts.find(list[(first + i) % list.size()]);
                if (it != hosts.end() && it->second->beginKeyboard()) break;
            }
        });
    }
    if (parser.isSet("settings")) profiles.current()->configure();
    if (smoke) QTimer::singleShot(700, &app, [&] {
        const QString configCapture = qEnvironmentVariable("PND_TEST_CAPTURE_SETTINGS");
        if (!configCapture.isEmpty() && !configWindow->grabWindow().save(configCapture)) configFailed = true;
        const QString capture = qEnvironmentVariable("PND_TEST_CAPTURE");
        if (!capture.isEmpty() && (hosts.empty() || !hosts.begin()->second->view()->grabWindow().save(capture))) configFailed = true;
        app.quit();
    });
    const int result = app.exec();
    bool failed = configFailed;
    for (const auto &entry : hosts) failed |= entry.second->failed() || entry.second->hasWarnings();
    return smoke && failed ? 1 : result;
}
