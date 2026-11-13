// SPDX-License-Identifier: GPL-2.0-or-later
#include "settings.h"
#include <QUrl>
#include <cmath>
#include <algorithm>
DockSettings::DockSettings(const QString &file, bool persistent, QObject *parent)
    : QObject(parent), m_store(file, QSettings::IniFormat), m_persistent(persistent)
{
    QVariantMap saved;
    if (persistent) for (const auto &key : defaults().keys()) saved[key] = m_store.value(key, defaults()[key]);
    m_values = normalized(saved);
}
QVariantMap DockSettings::defaults()
{
    return {{"edge", 0}, {"screen", ""}, {"iconSize", 40}, {"zoom", 1.5},
        {"radius", 10}, {"spacing", 8}, {"glow", false}, {"dodge", true}, {"launchers", QStringList{}}};
}
QVariantMap DockSettings::normalized(const QVariantMap &input)
{
    auto result = defaults();
    for (auto it = input.begin(); it != input.end(); ++it) if (result.contains(it.key())) result[it.key()] = it.value();
    const auto number = [&](const QString &key, double low, double high, bool integer) {
        bool ok;
        const double value = result[key].toDouble(&ok);
        result[key] = !ok || !std::isfinite(value) ? defaults()[key]
            : QVariant(integer ? std::round(std::clamp(value, low, high)) : std::clamp(value, low, high));
    };
    number("edge", 0, 3, true); number("iconSize", 24, 96, true);
    number("zoom", 1, 2.5, false); number("radius", 0, 96, true); number("spacing", 0, 128, true);
    result["screen"] = result["screen"].toString();
    result["glow"] = result["glow"].toBool(); result["dodge"] = result["dodge"].toBool();
    QStringList launchers;
    for (const auto &entry : result["launchers"].toStringList()) {
        const QUrl url(entry);
        if (!url.isValid() || !(url.scheme() == "applications" || url.isLocalFile())
            || !url.path().endsWith(".desktop") || url.hasQuery() || url.hasFragment()) continue;
        const QString canonical = url.toString(QUrl::FullyEncoded);
        if (!launchers.contains(canonical)) launchers << canonical;
    }
    result["launchers"] = launchers;
    return result;
}
bool DockSettings::apply(const QVariantMap &changes)
{
    auto merged = m_values;
    for (auto it = changes.begin(); it != changes.end(); ++it) merged[it.key()] = it.value();
    const auto next = normalized(merged);
    if (m_persistent) {
        for (auto it = next.begin(); it != next.end(); ++it) m_store.setValue(it.key(), it.value());
        m_store.sync();
        if (m_store.status() != QSettings::NoError) {
            m_error = tr("Could not save settings. Check that your configuration directory is writable.");
            Q_EMIT errorChanged(); return false;
        }
    }
    m_error.clear(); Q_EMIT errorChanged();
    if (m_values != next) { m_values = next; Q_EMIT changed(); }
    return true;
}
bool DockSettings::saveLaunchers(const QStringList &urls) { return apply({{"launchers", urls}}); }
void DockSettings::overrideSession(const QVariantMap &changes)
{
    auto merged = m_values;
    for (auto it = changes.begin(); it != changes.end(); ++it) merged[it.key()] = it.value();
    m_values = normalized(merged);
    Q_EMIT changed();
}
