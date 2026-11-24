// SPDX-License-Identifier: GPL-2.0-or-later
#include "launcherresolver.h"
#include <QDragEnterEvent>
#include <QMimeData>
#include <QQuickItem>
#include <QQuickWindow>
#include "controller.h"
#include "statussupport.h"
#include <QDBusConnection>
#include <QDBusMessage>
#include "popupanchor.h"
#include "applicationmenubackend.h"
#include "menutarget.h"
#include "windowpreviewmodel.h"
#include <QApplication>
#include <QMenu>
#include <clocale>
#include <QStandardItemModel>
#include <QStandardPaths>
#include <QProcess>
#include <QDir>
#include <KLocalizedQmlContext>
#include <KLocalizedString>
#include "icons.h"
#include "settings.h"
#include <QtQuickTest/quicktest.h>
#include <QQmlContext>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QIcon>
#include <QTemporaryDir>
#include <QFile>
#include <QUrl>
#include <QWheelEvent>
#include <QQuickItem>
class PreviewFixture : public QStandardItemModel
{
    Q_OBJECT
public:
    QString activated, closed;
    PreviewFixture() {
        setItemRoleNames({{Qt::DisplayRole, "display"}, {Qt::DecorationRole, "decoration"},
            {Qt::UserRole, "IsWindow"}, {Qt::UserRole + 1, "IsGroupParent"},
            {Qt::UserRole + 2, "IsClosable"}, {Qt::UserRole + 3, "IsActive"},
            {Qt::UserRole + 4, "IsMinimized"}, {Qt::UserRole + 5, "WinIdList"}});
        auto *group = new QStandardItem("Test group");
        group->setData(true, Qt::UserRole + 1);
        for (const auto &title : {"First window", "Second window"}) {
            auto *window = new QStandardItem(QString::fromLatin1(title));
            window->setData(true, Qt::UserRole);
            window->setData(true, Qt::UserRole + 2);
            window->setData(false, Qt::UserRole + 3);
            window->setData(false, Qt::UserRole + 4);
            window->setData(QStringLiteral("folder"), Qt::DecorationRole);
            group->appendRow(window);
        }
        appendRow(group);
    }
    Q_INVOKABLE void requestActivate(const QModelIndex &index) { activated = index.data().toString(); }
    Q_INVOKABLE void requestClose(const QModelIndex &index) { closed = index.data().toString(); }
};
class Setup : public QObject
{
    Q_OBJECT
    QStandardItemModel m_menuModel;
    PreviewFixture m_previewModel;
    QQmlEngine *m_engine = nullptr;
public:
    Q_INVOKABLE bool externalDrag(QQuickItem *item, const QPointF &point, const QList<QUrl> &urls, int phase) {
        if (!item || !item->window()) return false;
        QMimeData mime;
        mime.setUrls(urls);
        const QPoint p = item->mapToScene(point).toPoint();
        if (phase == 0) {
            QDragEnterEvent event(p, Qt::CopyAction, &mime, Qt::LeftButton, Qt::NoModifier);
            QCoreApplication::sendEvent(item->window(), &event);
            return event.isAccepted();
        }
        if (phase == 1) {
            QDragMoveEvent event(p, Qt::CopyAction, &mime, Qt::LeftButton, Qt::NoModifier);
            QCoreApplication::sendEvent(item->window(), &event);
            return event.isAccepted();
        }
        if (phase == 2) {
            QDropEvent event(p, Qt::CopyAction, &mime, Qt::LeftButton, Qt::NoModifier);
            QCoreApplication::sendEvent(item->window(), &event);
            return event.isAccepted();
        }
        QDragLeaveEvent event;
        QCoreApplication::sendEvent(item->window(), &event);
        return true;
    }
    Q_INVOKABLE bool detachStatusContext() {
        auto *context = new QQmlContext(m_engine->rootContext());
        QQmlComponent component(m_engine, QUrl(QStringLiteral("qrc:/qml/TaskStatus.qml")));
        auto *status = component.createWithInitialProperties({
            {QStringLiteral("task"), QVariantMap{{QStringLiteral("LauncherUrl"), QStringLiteral("applications:test.desktop")}}},
            {QStringLiteral("taskIndex"), 0}}, context);
        if (!status) { delete context; return false; }
        QQmlEngine::setObjectOwnership(status, QQmlEngine::CppOwnership);
        status->setParent(this);
        // Model delegates can lose their context before deferred QObject deletion.
        delete context;
        status->deleteLater();
        return true;
    }
    Q_INVOKABLE bool publishLauncher(const QVariantMap &properties) {
        auto message = QDBusMessage::createSignal("/test/launcher", "com.canonical.Unity.LauncherEntry", "Update");
        message << QStringLiteral("application://First.desktop") << properties;
        return QDBusConnection::sessionBus().send(message);
    }
    Q_INVOKABLE QString activatedPreview() const { return m_previewModel.activated; }
    Q_INVOKABLE QString closedPreview() const { return m_previewModel.closed; }
    Q_INVOKABLE QStringList menuTexts() const {
        QStringList result;
        for (auto *widget : QApplication::topLevelWidgets()) {
            auto *menu = qobject_cast<QMenu *>(widget);
            if (!menu || !menu->isVisible()) continue;
            for (auto *action : menu->actions()) result << QString(action->text()).remove(QLatin1Char('&'));
        }
        return result;
    }
    Q_INVOKABLE bool clickMenu(const QString &label) {
        for (auto *widget : QApplication::topLevelWidgets()) {
            auto *menu = qobject_cast<QMenu *>(widget);
            if (!menu || !menu->isVisible()) continue;
            for (auto *action : menu->actions()) if (QString(action->text()).remove(QLatin1Char('&')) == label) {
                action->trigger();
                menu->close();
                return true;
            }
        }
        return false;
    }
    Q_INVOKABLE bool translationLocaleAvailable() {
        // GNU gettext deliberately disables translation in the C locale.
        const QByteArray current = std::setlocale(LC_MESSAGES, nullptr);
        if (!current.startsWith("C") && current != "POSIX") return true;
        for (const char *candidate : {"fr_FR.UTF-8", "en_US.UTF-8"})
            if (std::setlocale(LC_MESSAGES, candidate)) return true;
        return false;
    }
    Q_INVOKABLE bool kdeFrenchAvailable() const {
        return KLocalizedString::availableDomainTranslations("plasma_applet_org.kde.plasma.taskmanager").contains("fr");
    }
    Q_INVOKABLE void language(const QString &language) { KLocalizedString::setLanguages({language}); m_engine->setUiLanguage(language); }
    Q_INVOKABLE void menuFixture(const QUrl &launcher, bool window = false) {
        m_menuModel.clear();
        m_menuModel.setItemRoleNames({{Qt::UserRole, "LauncherUrlWithoutIcon"},
            {Qt::UserRole + 1, "IsWindow"}, {Qt::UserRole + 2, "IsClosable"}});
        auto *item = new QStandardItem("Test application");
        item->setData(launcher, Qt::UserRole);
        item->setData(window, Qt::UserRole + 1);
        item->setData(window, Qt::UserRole + 2);
        m_menuModel.appendRow(item);
    }
    Q_INVOKABLE void removeMenuTask() { m_menuModel.removeRow(0); }
    Q_INVOKABLE void wheel(QQuickItem *item, QPointF position, QPoint delta, bool synthesized, bool pixels) {
        const QPointF scene = item->mapToScene(position);
        QWheelEvent event(scene, item->window()->mapToGlobal(scene), pixels ? delta : QPoint(),
                          pixels ? QPoint() : delta, Qt::NoButton, Qt::NoModifier,
                          Qt::NoScrollPhase, false, synthesized ? Qt::MouseEventSynthesizedBySystem : Qt::MouseEventNotSynthesized);
        QCoreApplication::sendEvent(item->window(), &event);
    }
    Q_INVOKABLE void behaviorOptions(const QVariantMap &changes) {
        auto options = m_engine->rootContext()->contextProperty("dockOptions").toMap();
        for (auto it = changes.begin(); it != changes.end(); ++it) options[it.key()] = it.value();
        m_engine->rootContext()->setContextProperty("dockOptions", options);
    }
    Q_INVOKABLE void hoverOptions(int radius, int lift) {
        auto options = m_engine->rootContext()->contextProperty("dockOptions").toMap();
        options["blastRadius"] = radius; options["hoverLift"] = lift;
        m_engine->rootContext()->setContextProperty("dockOptions", options);
    }
    Q_INVOKABLE void layoutOptions(int spacing, int ends, int thickness) {
        auto options = m_engine->rootContext()->contextProperty("dockOptions").toMap();
        options["iconSpacing"] = spacing; options["horizontalPadding"] = ends; options["verticalPadding"] = thickness;
        m_engine->rootContext()->setContextProperty("dockOptions", options);
    }
    Q_INVOKABLE void indicatorOptions(int mode) {
        auto options = m_engine->rootContext()->contextProperty("dockOptions").toMap();
        options["indicatorMode"] = mode;
        options["taskDecorations"] = 2;
        options["indicatorAnimations"] = true;
        options["indicatorStyle"] = 2;
        m_engine->rootContext()->setContextProperty("dockOptions", options);
    }
    Q_INVOKABLE void setEdge(int edge) {
        auto options = m_engine->rootContext()->contextProperty("dockOptions").toMap();
        options["edge"] = edge;
        m_engine->rootContext()->setContextProperty("dockOptions", options);
    }
public Q_SLOTS:
    void qmlEngineAvailable(QQmlEngine *engine) {
        m_engine = engine;
        KLocalizedString::setApplicationDomain("plasma-next-dock");
        KLocalizedString::addDomainLocaleDir("plasma-next-dock", QStringLiteral(DOCK_TEST_LOCALE));
        engine->rootContext()->setContextProperty("testMenuModel", &m_menuModel);
        engine->rootContext()->setContextProperty("testPreviewModel", &m_previewModel);
        auto *localized = new KLocalizedQmlContext(engine);
        localized->setTranslationDomain(QStringLiteral("plasma-next-dock"));
        engine->rootContext()->setContextObject(localized);
        QQmlEngine::setContextForObject(localized, engine->rootContext());
        engine->rootContext()->setContextProperty("statusSupport", new StatusSupport(engine));
        engine->rootContext()->setContextProperty("applicationMenus", new ApplicationMenuBackend(engine));
        engine->rootContext()->setContextProperty("menuTarget", new MenuTarget(engine));
        engine->rootContext()->setContextProperty("dropTarget", new MenuTarget(engine));
        engine->rootContext()->setContextProperty("launcherResolver", new LauncherResolver(engine));
        engine->rootContext()->setContextProperty("windowPreviews", new WindowPreviewModel(engine));
        engine->rootContext()->setContextProperty("testEnvironment", this);
        initializeIconPaths();
        engine->rootContext()->setContextProperty("dockMenuAnchor", new PopupAnchor(engine));
        const auto apps = QStandardPaths::writableLocation(QStandardPaths::ApplicationsLocation);
        const auto menus = QStandardPaths::writableLocation(QStandardPaths::ConfigLocation) + "/menus";
        QDir().mkpath(apps);
        QDir().mkpath(menus);
        QFile applicationsMenu(menus + "/applications.menu");
        if (!applicationsMenu.open(QIODevice::WriteOnly)) qFatal("Cannot write test menu fixture");
        applicationsMenu.write("<Menu><Name>Applications</Name><DefaultAppDirs/><Include><All/></Include></Menu>");
        applicationsMenu.close();
        QStringList urls;
        for (const auto &name : {"First", "Second"}) {
            const auto path = apps + "/" + QString::fromLatin1(name) + ".desktop";
            QFile file(path);
            if (!file.open(QIODevice::WriteOnly)) qFatal("Could not create isolated desktop-entry fixture");
            file.write((QString("[Desktop Entry]\nType=Application\nName=%1\nExec=/bin/true\nIcon=folder\nActions=Private;\n\n[Desktop Action Private]\nName=New Private Window\nExec=/bin/true --private\n").arg(name)).toUtf8());
            file.close(); urls << QUrl::fromLocalFile(path).toString();
        }
        if (QProcess::execute(QStringLiteral(DOCK_KBUILDSYCOCA), {QStringLiteral("--noincremental")}) != 0)
            qFatal("Could not build isolated test service cache");
        engine->rootContext()->setContextProperty("testLauncherUrls", urls);
        engine->rootContext()->setContextProperty("foldersSettingsUrl", QUrl::fromLocalFile(QStringLiteral(FOLDERS_PACKAGE) + "/Settings.qml"));
        engine->rootContext()->setContextProperty("unpinnedSettingsUrl", QUrl::fromLocalFile(QStringLiteral(UNPINNED_SETTINGS)));
        engine->rootContext()->setContextProperty("dockSettings", new DockSettings("/unused", false, engine));
        engine->rootContext()->setContextProperty("outputDescriptions", QVariantMap{
            {"DP-1", "AOC 2590G4"}, {"DP-2", QString("Samsung Electronics ").repeated(8)}});
        engine->rootContext()->setContextProperty("outputNames", QStringList{QString(), "DP-1", "DP-2", "HDMI-1"});
        engine->rootContext()->setContextProperty("dockController", new DockController(nullptr, engine));
        engine->rootContext()->setContextProperty("outputSize", QSize(1000, 700));
        engine->rootContext()->setContextProperty("outputGeometry", QRect(-1000, 0, 1000, 700));
        engine->rootContext()->setContextProperty("dockOptions", QVariantMap{
            {"demo", true}, {"edge", 0}, {"iconSize", 40}, {"zoom", 1.5}, {"radius", 10}, {"glow", true}, {"launchers", QStringList{}}});
    }
};
int main(int argc, char **argv) {
    Q_INIT_RESOURCE(docktestqml);
    // Fail once, before running dozens of QML cases against missing resources.
    QFile manifest(QStringLiteral(DOCK_RESOURCE_MANIFEST));
    if (!manifest.open(QIODevice::ReadOnly)) {
        qCritical("Cannot read dock resource manifest");
        return 1;
    }
    for (const auto &line : manifest.readAll().split('\n')) {
        if (line.isEmpty()) continue;
        QFile resource(QStringLiteral(":/") + QString::fromUtf8(line));
        if (!resource.open(QIODevice::ReadOnly) || resource.size() == 0) {
            qCritical("Missing or empty embedded test resource: %s", qPrintable(resource.fileName()));
            return 1;
        }
    }
    QTemporaryDir environment;
    qputenv("XDG_DATA_HOME", (environment.path() + "/data").toUtf8());
    qputenv("XDG_CONFIG_HOME", (environment.path() + "/config").toUtf8());
    qputenv("XDG_CACHE_HOME", (environment.path() + "/cache").toUtf8());
    QApplication app(argc, argv);
    Setup setup;
    return quick_test_main_with_setup(argc, argv, "hover", nullptr, &setup);
}
#include "hoverqmltest.moc"
