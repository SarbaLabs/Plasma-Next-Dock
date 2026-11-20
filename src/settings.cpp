// SPDX-License-Identifier: GPL-2.0-or-later
#include "settings.h"
#include <QUrl>
#include <QDir>
#include <QFileInfo>
#include <QColor>
#include <cmath>
#include <algorithm>
DockSettings::DockSettings(const QString &file, bool persistent, QObject *parent, const QString &loginTemplate, const QString &group)
    : QObject(parent), m_store(file, QSettings::IniFormat), m_persistent(persistent),
      m_loginTemplate(loginTemplate),
      m_loginEntry(QFileInfo(file).dir().filePath("autostart/org.sarbalabs.PlasmaNextDock.desktop"))
{
    if (!group.isEmpty()) m_store.beginGroup(group);
    QVariantMap saved;
    if (persistent) {
        for (const auto &key : defaults().keys())
            if (m_store.contains(key)) saved[key] = m_store.value(key);
    }
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
        {"grayscaleIcons", false}, {"tintIcons", false}, {"iconTintRole", "highlight"},
        {"iconTintColor", "#3daee9"}, {"iconTintSaturation", 100},
        {"blastRadius", 2}, {"hoverLift", 0}, {"radius", 10}, {"spacing", 8}, {"glow", false}, {"glowRadius", 0}, {"glowIntensity", 100}, {"glowOpacity", 30}, {"dodge", true}, {"visibilityMode", 2}, {"dockAlignment", 1}, {"alignmentMargin", 0}, {"launchers", QStringList{}},
        {"bounceEnabled", true}, {"bounceOnLaunch", true}, {"bounceOnAttention", true},
        {"bounceHeight", 0}, {"bounceSpeed", 100}, {"bounceCount", 3},
        {"groupApplications", true}, {"groupingAppIdBlacklist", QStringList{}},
        {"groupingLauncherUrlBlacklist", QStringList{}}, {"taskSort", 0}, {"groupClick", 0},
        {"minimizeActive", false}, {"middleClick", 0}, {"wheelAction", 0}, {"skipMinimized", true},
        {"filterDesktop", true}, {"filterActivity", true}, {"filterScreen", false}, {"onlyMinimized", false},
        {"layoutDirection", 0}, {"showSeparator", true}, {"revealAttention", false},
        {"showWindowPreviews", true}, {"highlightPreviewWindow", true}, {"showAudioIndicator", true}, {"muteOnClick", true},
        {"showMediaControls", true}, {"showBadges", true}, {"showProgress", true},
        {"topLeftRadius", 10}, {"topRightRadius", 10}, {"bottomRightRadius", 10}, {"bottomLeftRadius", 10},
        {"backgroundRole", "automatic"}, {"backgroundColor", "#303030"}, {"gradientTopRole", "window"}, {"gradientTopColor", "#303030"}, {"gradientBottomRole", "highlight"},
        {"gradientBottomColor", "#3daee9"}, {"gradientTopOpacity", 1.0}, {"gradientBottomOpacity", 1.0},
        {"borderRole", "automatic"}, {"borderOpacity", 1.0}, {"backgroundType", 0}, {"backgroundOpacity", 1.0}, {"glassOpacity", 0.35}, {"systemBlur", false}, {"gradientMidpoint", 50},
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
    const int oldMode = result["backgroundType"].toInt();
    if (!input.contains("systemBlur")) {
        result["systemBlur"] = oldMode == 3 || oldMode == 4;
        result["glassOpacity"] = input.value("backgroundOpacity", 0.35);
        if (oldMode == 1) result["borderOpacity"] = 0.0;
        if (oldMode == 1) result["backgroundOpacity"] = 0.0;
        else if (oldMode == 2 || oldMode == 3) result["backgroundOpacity"] = input.value("backgroundOpacity", 0.35);
        else if (oldMode >= 0 && oldMode <= 5) result["backgroundOpacity"] = 1.0;
    }
    result["backgroundType"] = oldMode == 4 || oldMode == 5 ? oldMode : 0;
    result["systemBlur"] = result["systemBlur"].toBool();
    number("gradientMidpoint", 1, 99, true);
    number("glassOpacity", 0, 1, false);
    for (const auto key : {"topLeftRadius", "topRightRadius", "bottomRightRadius", "bottomLeftRadius"}) {
        if (!input.contains(key)) result[key] = result["radius"];
        number(key, -96, 96, true);
    }
    if (!input.contains("borderRole") && !result["borderUseTheme"].toBool()) result["borderRole"] = "custom";
    for (const auto key : {"backgroundColor", "gradientTopColor", "gradientBottomColor", "iconTintColor"})
        if (!QColor::isValidColorName(result[key].toString())) result[key] = defaults()[key];
    for (const auto key : {"borderOpacity", "gradientTopOpacity", "gradientBottomOpacity"}) number(key, 0, 1, false);
    number("backgroundOpacity", 0, 1, false);
    number("borderWidth", 0, 12, true);
    number("iconSpacing", 0, 64, true); number("horizontalPadding", 0, 128, true); number("verticalPadding", 0, 64, true);
    result["borderUseTheme"] = result["borderRole"].toString() != "custom";
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
    for (const auto &key : {"showWindowPreviews", "highlightPreviewWindow", "showAudioIndicator", "muteOnClick", "showMediaControls", "showBadges", "showProgress"})
        result[key] = result[key].toBool();
    result["screen"] = result["screen"].toString();
    result["glow"] = result["glow"].toBool();
    number("glowRadius", 0, 256, true);
    number("glowIntensity", 0, 200, true);
    result["grayscaleIcons"] = result["grayscaleIcons"].toBool();
    result["tintIcons"] = result["tintIcons"].toBool();
    number("iconTintSaturation", 0, 100, true);
    number("glowOpacity", 0, 100, true);
    if (!input.contains("visibilityMode")) result["visibilityMode"] = result["dodge"].toBool() ? 2 : 3;
    number("visibilityMode", 0, 3, true);
    number("dockAlignment", 0, 2, true);
    number("alignmentMargin", 0, 512, true);
    result["dodge"] = result["visibilityMode"].toInt() == 2;

    for (const auto *key : {"groupingAppIdBlacklist", "groupingLauncherUrlBlacklist"})
        result[key] = result[key].toStringList();
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
static QVariantMap mergeChanges(QVariantMap merged, const QVariantMap &changes)
{
    for (auto it = changes.begin(); it != changes.end(); ++it) merged[it.key()] = it.value();
    if (changes.contains("dodge") && !changes.contains("visibilityMode"))
        merged["visibilityMode"] = changes["dodge"].toBool() ? 2 : 3;
    if (changes.contains("radius")) {
        for (const auto key : {"topLeftRadius", "topRightRadius", "bottomRightRadius", "bottomLeftRadius"})
            if (!changes.contains(key)) merged[key] = changes["radius"];
    }
    if (changes.contains("borderUseTheme") && !changes.contains("borderRole"))
        merged["borderRole"] = changes["borderUseTheme"].toBool() ? "automatic" : "custom";
    return DockSettings::normalized(merged);
}
bool DockSettings::apply(const QVariantMap &changes)
{
    const auto next = mergeChanges(m_values, changes);
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
    m_values = mergeChanges(m_values, changes);
    Q_EMIT changed();
}
