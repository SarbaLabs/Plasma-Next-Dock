// SPDX-License-Identifier: GPL-2.0-or-later
#include "panelreservation.h"
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusServiceWatcher>
#include <QJsonArray>
#include <QJsonDocument>
#include <QScreen>
#include <QStandardPaths>

static const QString shell = QStringLiteral("org.kde.plasmashell");

PanelReservation::PanelReservation(QScreen *screen, DockGeometry::Edge edge)
    : m_screen(screen), m_edge(edge)
{
    m_delay.setSingleShot(true);
    connect(&m_delay, &QTimer::timeout, this, &PanelReservation::query);
    const auto config = QStandardPaths::writableLocation(QStandardPaths::ConfigLocation);
    m_files.addFile(config + QStringLiteral("/plasmashellrc"));
    m_files.addFile(config + QStringLiteral("/plasma-org.kde.plasma.desktop-appletsrc"));
    connect(&m_files, &KDirWatch::dirty, this, &PanelReservation::schedule);
    connect(&m_files, &KDirWatch::created, this, &PanelReservation::schedule);
    connect(&m_files, &KDirWatch::deleted, this, &PanelReservation::schedule);
    connect(screen, &QScreen::geometryChanged, this, &PanelReservation::schedule);
    auto *service = new QDBusServiceWatcher(shell, QDBusConnection::sessionBus(),
                                            QDBusServiceWatcher::WatchForOwnerChange, this);
    connect(service, &QDBusServiceWatcher::serviceOwnerChanged, this, [this] {
        setThickness(0);
        schedule();
    });
    query();
}

void PanelReservation::schedule()
{
    ++m_revision;
    m_startupRetries = 0;
    m_delay.start(200);
}

void PanelReservation::setThickness(int value)
{
    if (m_thickness == value) return;
    m_thickness = value;
    Q_EMIT changed();
}

void PanelReservation::query()
{
    // StrutManager's availableScreenRect also counts floating artwork and
    // panels that let windows underneath. Only normal panels reserve height.
    // Plasma 6.3 stacks them; from 6.4 the thickest panel on the edge reserves.
    static const QStringList edges{"bottom", "top", "left", "right"};
    const auto args = QJsonDocument(QJsonArray{m_screen->name(), edges.at(m_edge)}).toJson(QJsonDocument::Compact);
    const QString script = QStringLiteral(R"JS((function(args) {
        var screen = screenForConnector(args[0]);
        if (screen < 0 || !desktops().length) return -1;
        var version = applicationVersion.split(".");
        var stack = Number(version[0]) === 6 && Number(version[1]) < 4;
        return panels().reduce(function(space, panel) {
            if (panel.screen !== screen || panel.location !== args[1] || panel.hiding !== "none") return space;
            return stack ? space + panel.height : Math.max(space, panel.height);
        }, 0);
    })(%1))JS").arg(QString::fromUtf8(args));
    auto msg = QDBusMessage::createMethodCall(shell, QStringLiteral("/PlasmaShell"),
        QStringLiteral("org.kde.PlasmaShell"), QStringLiteral("evaluateScript"));
    msg.setAutoStartService(false);
    msg << QStringLiteral("print(") + script + QLatin1Char(')');
    auto *call = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(msg), this);
    connect(call, &QDBusPendingCallWatcher::finished, this, [this, call, revision = m_revision] {
        QDBusPendingReply<QString> result = *call;
        call->deleteLater();
        if (revision != m_revision || result.isError()) return;
        bool ok = false;
        const int size = result.value().trimmed().toInt(&ok);
        if (ok && size >= 0) setThickness(size);
        else if (m_startupRetries < 5) m_delay.start(500 << m_startupRetries++);
    });
}
