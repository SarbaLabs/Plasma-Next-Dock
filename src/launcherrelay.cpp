// SPDX-License-Identifier: GPL-2.0-or-later
#include "launcherrelay.h"
#include <KPluginMetaData>
#include <KSignalHandler>
#include <csignal>
#include <QCoreApplication>
#include <QDBusConnection>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusServiceWatcher>
#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QStandardPaths>

namespace {
const QString shell = QStringLiteral("org.kde.plasmashell");
const QString relay = QStringLiteral("org.sarbalabs.nextdock.launcherrelay");
QString json(const QStringList &list)
{
    return QString::fromUtf8(QJsonDocument(QJsonArray::fromStringList(list)).toJson(QJsonDocument::Compact));
}
QStringList providers()
{
    QStringList ids;
    auto consider = [&](const KPluginMetaData &meta) {
        if (meta.pluginId() != relay && meta.value(QStringLiteral("X-Plasma-Provides"), QStringList()).contains(QStringLiteral("org.kde.plasma.launchermenu")))
            ids.append(meta.pluginId());
    };
    for (const auto &meta : KPluginMetaData::findPlugins(QStringLiteral("plasma/applets"))) consider(meta);
    for (const auto &dir : QStandardPaths::locateAll(QStandardPaths::GenericDataLocation, QStringLiteral("plasma/plasmoids"), QStandardPaths::LocateDirectory)) {
        for (const auto &entry : QDir(dir).entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot)) {
            const QString path = entry.absoluteFilePath() + QStringLiteral("/metadata.json");
            if (QFile::exists(path)) consider(KPluginMetaData::fromJsonFile(path));
        }
    }
    ids.removeDuplicates();
    return ids;
}
}
void LauncherRelay::start()
{
    auto bus = QDBusConnection::sessionBus();
    if (!bus.registerService(QStringLiteral("org.sarbalabs.PlasmaNextDock"))
        || !bus.registerObject(QStringLiteral("/Launcher"), this, QDBusConnection::ExportAllSlots)) return;
    m_running = true;
    const QString layoutFile = QStandardPaths::writableLocation(QStandardPaths::ConfigLocation) + QStringLiteral("/plasma-org.kde.plasma.desktop-appletsrc");
    m_delay.setSingleShot(true);
    connect(&m_delay, &QTimer::timeout, this, [this] { synchronize(); });
    m_watcher.addFile(layoutFile);
    const auto metadata = QStandardPaths::locate(QStandardPaths::GenericDataLocation, QStringLiteral("plasma/plasmoids/") + relay + QStringLiteral("/metadata.json"));
    if (!metadata.isEmpty()) m_watcher.addFile(metadata);
    connect(&m_watcher, &KDirWatch::dirty, this, &LauncherRelay::schedule);
    connect(&m_watcher, &KDirWatch::deleted, this, &LauncherRelay::schedule);
    connect(&m_watcher, &KDirWatch::created, this, &LauncherRelay::schedule);
    KSignalHandler::self()->watchSignal(SIGTERM);
    connect(KSignalHandler::self(), &KSignalHandler::signalReceived, this, [](int sig) {
        if (sig == SIGTERM) QCoreApplication::quit();
    });
    auto *watcher = new QDBusServiceWatcher(shell, bus, QDBusServiceWatcher::WatchForRegistration, this);
    connect(watcher, &QDBusServiceWatcher::serviceRegistered, this, &LauncherRelay::schedule);
    bus.connect(QStringLiteral("org.kde.ActivityManager"), QStringLiteral("/ActivityManager/Activities"),
                QStringLiteral("org.kde.ActivityManager.Activities"), QStringLiteral("CurrentActivityChanged"), this, SLOT(schedule()));
    connect(qApp, &QCoreApplication::aboutToQuit, this, [this] { synchronize(true); });
    schedule();
}
void LauncherRelay::setOutputs(QStringList names)
{
    names.removeDuplicates();
    if (m_outputs == names) return;
    m_outputs = names;
    schedule();
}
void LauncherRelay::schedule()
{
    m_retries = 0;
    if (m_running) m_delay.start(350);
}
void LauncherRelay::synchronize(bool stopping)
{
    QFile file(QStringLiteral(":/relay/sync-launcher-relay.js"));
    if (!file.open(QIODevice::ReadOnly)) return;
    QString script = QString::fromUtf8(file.readAll());
    script.replace(QStringLiteral("LAUNCHER_PROVIDERS"), json(providers()));
    const bool installed = !QStandardPaths::locate(QStandardPaths::GenericDataLocation, QStringLiteral("plasma/plasmoids/") + relay + QStringLiteral("/metadata.json")).isEmpty();
    script.replace(QStringLiteral("OUTPUT_NAMES"), json(stopping || !installed ? QStringList{} : m_outputs));
    auto msg = QDBusMessage::createMethodCall(shell, QStringLiteral("/PlasmaShell"), QStringLiteral("org.kde.PlasmaShell"), QStringLiteral("evaluateScript"));
    msg.setAutoStartService(false);
    msg << script;
    if (stopping) {
        QDBusConnection::sessionBus().call(msg, QDBus::Block, 1000);
        return;
    }
    auto *pending = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(msg), this);
    connect(pending, &QDBusPendingCallWatcher::finished, this, [this, pending] {
        QDBusPendingReply<QString> reply = *pending;
        // On session login the bus name can precede Plasma's first desktop.
        if (!reply.isError() && reply.value().trimmed() == QStringLiteral("pending") && m_retries < 5)
            m_delay.start(500 << m_retries++);
        if (reply.isError()) qWarning() << "Plasma launcher relay:" << reply.error().message();
        pending->deleteLater();
    });
}
void LauncherRelay::Activate()
{
    if (m_outputs.isEmpty()) return;
    // Plasma can fall back to a launcher on another monitor. Only open a
    // dock menu if the relay belongs to KWin's currently active output.
    auto msg = QDBusMessage::createMethodCall(QStringLiteral("org.kde.KWin"), QStringLiteral("/KWin"), QStringLiteral("org.kde.KWin"), QStringLiteral("activeOutputName"));
    auto *watch = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(msg), this);
    connect(watch, &QDBusPendingCallWatcher::finished, this, [this, watch] {
        QDBusPendingReply<QString> reply = *watch;
        watch->deleteLater();
        if (!reply.isError() && m_outputs.contains(reply.value())) Q_EMIT requested(reply.value());
    });
}
