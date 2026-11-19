// SPDX-License-Identifier: GPL-2.0-or-later
#include "dockprofiles.h"
#include <KLocalizedString>

DockProfiles::DockProfiles(const QString &file, bool persistent, const QString &loginTemplate)
    : m_file(file), m_persistent(persistent), m_loginTemplate(loginTemplate)
{
    if (persistent) {
        for (const QString &id : QSettings(file, QSettings::IniFormat).value("collection/ids").toStringList()) {
            const int number = id.toInt();
            if (number > 0 && QString::number(number) == id && !m_ids.contains(id)) m_ids << id;
        }
    }
    if (m_ids.isEmpty()) m_ids << QStringLiteral("1");
    for (const auto &id : m_ids) m_profiles << create(id);
    m_current = m_profiles.first();
}
DockSettings *DockProfiles::create(const QString &id)
{
    // The original flat configuration remains the first profile, also on upgrade.
    auto *profile = new DockSettings(m_file, m_persistent, this, m_loginTemplate,
                                     id == "1" ? QString() : "docks/" + id);
    connect(profile, &DockSettings::changed, this, &DockProfiles::profileChanged);
    connect(profile, &DockSettings::configureRequested, this, [this, profile] {
        select(m_profiles.indexOf(profile));
        Q_EMIT openRequested();
    });
    return profile;
}
QStringList DockProfiles::labels() const
{
    QStringList result;
    for (const auto &id : m_ids) result << i18n("Dock %1", id);
    return result;
}
void DockProfiles::select(int index)
{
    if (index < 0 || index >= m_profiles.size() || m_profiles.at(index) == m_current) return;
    m_current = m_profiles.at(index);
    Q_EMIT selectionChanged();
}
void DockProfiles::setOutputs(const QStringList &outputs, const QString &primary)
{
    m_outputs = outputs;
    m_primary = primary;
}
bool DockProfiles::occupied(const QString &screen, int edge, DockSettings *except) const
{
    const QString output = screen.isEmpty() ? m_primary : screen;
    for (auto *profile : m_profiles) {
        if (profile == except) continue;
        const auto settings = profile->values();
        const auto name = settings["screen"].toString();
        if ((name.isEmpty() ? m_primary : name) == output && settings["edge"].toInt() == edge) return true;
    }
    return false;
}
bool DockProfiles::positionAvailable(const QString &screen, int edge) const
{
    const auto current = m_current->values();
    return (screen == current["screen"].toString() && edge == current["edge"].toInt())
        || !occupied(screen, edge, m_current);
}
QString DockProfiles::assignedOutput(DockSettings *profile) const
{
    // A primary-screen change can make two saved positions coincide. Keep the
    // first dock on that edge until the outputs separate again.
    const auto requested = profile->values();
    const QString preferred = requested["screen"].toString();
    const QString wanted = preferred.isEmpty() ? m_primary : preferred;
    bool anyConnected = false;
    for (auto *candidate : m_profiles) {
        const auto values = candidate->values();
        QString name = values["screen"].toString();
        if (name.isEmpty()) name = m_primary;
        if (!m_outputs.contains(name)) continue;
        anyConnected = true;
        if (values["edge"] == requested["edge"] && name == wanted)
            return candidate == profile ? name : QString();
    }
    // Keep settings reachable if every explicitly selected output disappeared.
    return !anyConnected && profile == m_profiles.first() ? m_primary : QString();
}
bool DockProfiles::storeIds(const QStringList &ids)
{
    if (!m_persistent) return true;
    QSettings store(m_file, QSettings::IniFormat);
    store.setValue("collection/ids", ids);
    store.sync();
    return store.status() == QSettings::NoError;
}
bool DockProfiles::add()
{
    QStringList screens = m_outputs;
    screens.removeAll(m_primary);
    screens.prepend(QString());
    for (const auto &name : screens) {
        for (int edge : {0, 1, 2, 3}) {
            if (occupied(name, edge, nullptr)) continue;
            int number = 2;
            while (m_ids.contains(QString::number(number))) ++number;
            const QString id = QString::number(number);
            auto *profile = create(id);
            auto initial = DockSettings::defaults();
            initial["edge"] = edge;
            initial["screen"] = name;
            if (!profile->apply(initial) || !storeIds(m_ids + QStringList{id})) {
                delete profile;
                return false;
            }
            m_ids << id;
            m_profiles << profile;
            m_current = profile;
            Q_EMIT listChanged();
            Q_EMIT selectionChanged();
            return true;
        }
    }
    return false;
}
bool DockProfiles::removeSelected()
{
    if (m_profiles.size() < 2) return false;
    const int index = selectedIndex();
    auto ids = m_ids;
    const QString id = ids.takeAt(index);
    if (m_persistent) {
        QSettings store(m_file, QSettings::IniFormat);
        store.setValue("collection/ids", ids);
        if (id == "1") {
            for (const auto &key : DockSettings::defaults().keys()) store.remove(key);
        } else store.remove("docks/" + id);
        store.sync();
        if (store.status() != QSettings::NoError) return false;
    }
    auto *removed = m_profiles.takeAt(index);
    m_ids = ids;
    m_current = m_profiles.at(qMin(index, int(m_profiles.size()) - 1));
    Q_EMIT selectionChanged();
    Q_EMIT listChanged();
    removed->deleteLater();
    return true;
}
