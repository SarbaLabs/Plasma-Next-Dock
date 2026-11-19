// SPDX-License-Identifier: GPL-2.0-or-later
#include "settings.h"
#include <QUrl>
#include <QDir>
#include <QFileInfo>
#include <QColor>
#include <cmath>
#include <algorithm>
DockSettings::DockSettings(const QString &file, bool persistent, QObject *parent, const QString &loginTemplate)
    : QObject(parent), m_store(file, QSettings::IniFormat), m_persistent(persistent),
      m_loginTemplate(loginTemplate),
      m_loginEntry(QFileInfo(file).dir().filePath("autostart/org.sarbalabs.PlasmaNextDock.desktop"))
{
    QVariantMap saved;
    if (persistent) for (const auto &key : defaults().keys()) saved[key] = m_store.value(key, defaults()[key]);
    m_values = normalized(saved);
}
bool DockSettings::startsAtLogin() const
{
    return loginAvailable() && QFileInfo(m_loginEntry).symLinkTarget() == m_loginTemplate;
}
bool DockSettings::setStartAtLogin(bool enabled)
{
    if (!loginAvailable()) return false;
    if (startsAtLogin() == enabled) return true;
    if (!enabled) return QFile::remove(m_loginEntry);
    return QFileInfo(m_loginTemplate).isFile()
        && QDir().mkpath(QFileInfo(m_loginEntry).absolutePath())
        && QFile::link(m_loginTemplate, m_loginEntry);
}
QVariantMap DockSettings::defaults()
{
    return {{"edge", 0}, {"screen", ""}, {"iconSize", 40}, {"zoom", 1.5},
        {"blastRadius", 2}, {"hoverLift", 0}, {"radius", 10}, {"spacing", 8}, {"glow", false}, {"dodge", true}, {"launchers", QStringList{}}, {"revealAnimation", true},
        {"bounceEnabled", true}, {"bounceOnLaunch", true}, {"bounceOnAttention", true},
        {"bounceHeight", 0}, {"bounceSpeed", 100}, {"bounceCount", 3},
        {"groupApplications", true}, {"taskSort", 0}, {"groupClick", 0},
        {"minimizeActive", false}, {"middleClick", 0}, {"wheelAction", 0}, {"skipMinimized", true},
        {"filterDesktop", true}, {"filterActivity", true}, {"filterScreen", false}, {"onlyMinimized", false},
        {"layoutDirection", 0}, {"showSeparator", true}, {"revealAttention", false},
        {"showWindowPreviews", true}, {"showAudioIndicator", true}, {"muteOnClick", true},
        {"showMediaControls", true}, {"showBadges", true}, {"showProgress", true},
        {"backgroundType", 0}, {"backgroundOpacity", 0.35},
        {"borderWidth", 1}, {"borderUseTheme", true}, {"borderColor", "#808080"},
        {"iconSpacing", 10}, {"horizontalPadding", 12}, {"verticalPadding", 10},
        {"indicatorUnfocusedColorEnabled", false},
        {"indicatorUnfocusedColor", "#3daee9"},
        {"indicatorMode", 0}, {"iconHoverHighlight", true},
        {"nativeGroupIndicator", 0},
        {"taskDecorations", 0},
        {"customIndicatorsEnabled", true},
        {"indicatorAnimations", true},
        {"indicatorStyle", 0},
        {"indicatorOverride", false},
        {"indicatorEdge", 0},
        {"indicatorEdgeDistance", 2},
        {"indicatorThickness", 4},
        {"indicatorLength", 12},
        {"indicatorRoundness", 100},
        {"indicatorSpacing", 2},
        {"indicatorAlignment", 1},
        {"indicatorResizeActive", true},
        {"indicatorActiveThickness", 5},
        {"indicatorActiveLength", 20},
        {"indicatorResizeHover", false},
        {"indicatorHoverSeparate", true},
        {"indicatorHoverThickness", 6},
        {"indicatorHoverLength", 24},
        {"indicatorGroupSeparate", false},
        {"indicatorGroupThickness", 4},
        {"indicatorGroupLength", 8},
        {"indicatorMaxSegments", 4},
        {"indicatorHighlightActive", true},
        {"indicatorDimInactive", true},
        {"indicatorInactiveOpacity", 55},
        {"indicatorDesaturate", false},
        {"indicatorColorSource", 0},
        {"indicatorCustomColor", "#3daee9"}};
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
    for (const auto &key : {"iconHoverHighlight", "bounceEnabled", "bounceOnLaunch", "bounceOnAttention", "groupApplications", "minimizeActive", "skipMinimized", "filterDesktop",
                           "filterActivity", "filterScreen", "onlyMinimized", "showSeparator", "revealAttention"})
        result[key] = result[key].toBool();
    for (const auto &[key, maximum] : {std::pair{"taskSort", 4}, {"groupClick", 2},
                                     {"middleClick", 3}, {"wheelAction", 1}, {"layoutDirection", 2}}) {
        bool ok = false;
        const int value = result[key].toInt(&ok);
        result[key] = ok && value >= 0 && value <= maximum ? value : defaults()[key];
    }
    number("bounceHeight", 0, 64, true); number("bounceSpeed", 50, 200, true); number("bounceCount", 1, 5, true);
    number("edge", 0, 3, true); number("iconSize", 24, 96, true);
    number("blastRadius", 0, 8, true); number("hoverLift", 0, 64, true);
    number("zoom", 1, 2.5, false); number("radius", 0, 96, true); number("spacing", 0, 128, true);
    if (result["backgroundType"].toInt() < 0 || result["backgroundType"].toInt() > 4) result["backgroundType"] = 0;
    number("backgroundType", 0, 4, true); number("backgroundOpacity", 0, 1, false);
    number("borderWidth", 0, 12, true);
    number("iconSpacing", 0, 64, true); number("horizontalPadding", 0, 128, true); number("verticalPadding", 0, 64, true);
    result["borderUseTheme"] = result["borderUseTheme"].toBool();
    result["borderColor"] = QColor::isValidColorName(result["borderColor"].toString()) ? result["borderColor"].toString() : defaults()["borderColor"];
    result["indicatorUnfocusedColorEnabled"] = result["indicatorUnfocusedColorEnabled"].toBool();
    result["indicatorUnfocusedColor"] = QColor::isValidColorName(result["indicatorUnfocusedColor"].toString()) ? result["indicatorUnfocusedColor"].toString() : defaults()["indicatorUnfocusedColor"];
    if (result["indicatorMode"].toInt() < 0 || result["indicatorMode"].toInt() > 2) result["indicatorMode"] = 0;
    number("indicatorMode", 0, 2, true);
    number("nativeGroupIndicator", 0, 2, true);
    number("taskDecorations", 0, 2, true);
    result["customIndicatorsEnabled"] = result["customIndicatorsEnabled"].toBool();
    result["indicatorAnimations"] = result["indicatorAnimations"].toBool();
    number("indicatorStyle", 0, 2, true);
    result["indicatorOverride"] = result["indicatorOverride"].toBool();
    number("indicatorEdge", 0, 3, true);
    number("indicatorEdgeDistance", 0, 32, true);
    number("indicatorThickness", 1, 24, true);
    number("indicatorLength", 1, 160, true);
    number("indicatorRoundness", 0, 100, true);
    number("indicatorSpacing", 0, 16, true);
    number("indicatorAlignment", 0, 2, true);
    result["indicatorResizeActive"] = result["indicatorResizeActive"].toBool();
    number("indicatorActiveThickness", 1, 24, true);
    number("indicatorActiveLength", 1, 160, true);
    result["indicatorResizeHover"] = result["indicatorResizeHover"].toBool();
    result["indicatorHoverSeparate"] = result["indicatorHoverSeparate"].toBool();
    number("indicatorHoverThickness", 1, 24, true);
    number("indicatorHoverLength", 1, 160, true);
    result["indicatorGroupSeparate"] = result["indicatorGroupSeparate"].toBool();
    number("indicatorGroupThickness", 1, 24, true);
    number("indicatorGroupLength", 1, 160, true);
    number("indicatorMaxSegments", 1, 8, true);
    result["indicatorHighlightActive"] = result["indicatorHighlightActive"].toBool();
    result["indicatorDimInactive"] = result["indicatorDimInactive"].toBool();
    number("indicatorInactiveOpacity", 0, 100, true);
    result["indicatorDesaturate"] = result["indicatorDesaturate"].toBool();
    number("indicatorColorSource", 0, 2, true);
    result["indicatorCustomColor"] = QColor::isValidColorName(result["indicatorCustomColor"].toString()) ? result["indicatorCustomColor"].toString() : defaults()["indicatorCustomColor"];
    for (const auto &key : {"showWindowPreviews", "showAudioIndicator", "muteOnClick", "showMediaControls", "showBadges", "showProgress"})
        result[key] = result[key].toBool();
    result["revealAnimation"] = result["revealAnimation"].toBool();
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
