// SPDX-License-Identifier: GPL-2.0-or-later
#include "dockprofiles.h"
#include <QTemporaryDir>
#include <QTest>
#include <limits>
class SettingsTest : public QObject
{
    Q_OBJECT
private Q_SLOTS:
    void independentDocksAndOutputs() {
        QTemporaryDir dir;
        const auto file = dir.filePath("dock.ini");
        const QStringList pins{"applications:org.kde.dolphin.desktop"};
        QVERIFY(DockSettings(file).apply({{"screen", "Samsung"}, {"edge", 2}, {"launchers", pins}, {"zoom", 2.0}}));
        {
            DockProfiles docks(file, true, {});
            docks.setOutputs({"Samsung", "AOC"}, "Samsung");
            auto *first = docks.current();
            QCOMPARE(first->values()["launchers"].toStringList(), pins);
            QVERIFY(docks.add());
            auto *second = docks.current();
            QVERIFY(second != first);
            QVERIFY(second->values()["launchers"].toStringList().isEmpty());
            QVERIFY(!docks.positionAvailable("", 2));
            QVERIFY(second->apply({{"screen", "AOC"}, {"edge", 2}, {"glow", true}}));
            QCOMPARE(docks.assignedOutput(first), "Samsung");
            QCOMPARE(docks.assignedOutput(second), "AOC");
            docks.setOutputs({"Samsung"}, "Samsung");
            QCOMPARE(docks.assignedOutput(second), QString());
            QCOMPARE(second->values()["screen"], "AOC");
            docks.setOutputs({"other"}, "other");
            QCOMPARE(docks.assignedOutput(first), "other");
            QCOMPARE(docks.assignedOutput(second), QString());
            first->configure();
            QCOMPARE(docks.current(), first);
            QCOMPARE(first->values()["zoom"], 2.0);
            QCOMPARE(first->values()["glow"], false);
        }
        DockProfiles restored(file, true, {});
        restored.setOutputs({"Samsung", "AOC"}, "Samsung");
        QCOMPARE(restored.profiles().size(), 2);
        QCOMPARE(restored.current()->values()["launchers"].toStringList(), pins);
        QVERIFY(restored.removeSelected());
        QCOMPARE(restored.assignedOutput(restored.current()), "AOC");
        QCOMPARE(restored.current()->values()["glow"], true);
        QVERIFY(!restored.removeSelected());
        QCOMPARE(DockProfiles(file, true, {}).profiles().size(), 1);
    }
    void optionalLoginEntry() {
        QTemporaryDir dir;
        QVERIFY(dir.isValid());
        const auto config = dir.filePath("dock.ini");
        const auto target = dir.filePath("installed template.desktop");
        const auto entry = dir.filePath("autostart/org.sarbalabs.PlasmaNextDock.desktop");
        DockSettings settings(config, true, nullptr, target);
        QVERIFY(!settings.startsAtLogin());
        QVERIFY(!settings.setStartAtLogin(true)); // Missing installation.
        QFile desktop(target);
        QVERIFY(desktop.open(QIODevice::WriteOnly));
        desktop.close();
        QVERIFY(settings.setStartAtLogin(true));
        QVERIFY(settings.setStartAtLogin(true));
        QCOMPARE(QFileInfo(entry).symLinkTarget(), target);
        DockSettings restored(config, true, nullptr, target);
        QVERIFY(restored.startsAtLogin());
        DockSettings demo(config, false, nullptr, target);
        QVERIFY(!demo.startsAtLogin());
        QVERIFY(!demo.setStartAtLogin(false));
        QVERIFY(restored.setStartAtLogin(false));
        QVERIFY(!QFileInfo(entry).isSymLink());
        QVERIFY(restored.setStartAtLogin(false));
        QFile foreign(entry);
        QVERIFY(foreign.open(QIODevice::WriteOnly));
        foreign.close();
        QVERIFY(!settings.setStartAtLogin(true));
        QVERIFY(QFileInfo(entry).isFile());
        QVERIFY(!QFileInfo(entry).isSymLink());
    }
    void hoverHighlightPersistence() {
        QTemporaryDir dir; const auto file = dir.filePath("dock.ini");
        DockSettings settings(file);
        QVERIFY(settings.values()["iconHoverHighlight"].toBool());
        QVERIFY(settings.apply({{"iconHoverHighlight", false}}));
        QVERIFY(!DockSettings(file).values()["iconHoverHighlight"].toBool());
    }
    void bouncePersistence() {
        QTemporaryDir dir; const auto file = dir.filePath("dock.ini");
        DockSettings settings(file);
        QVERIFY(settings.values()["bounceEnabled"].toBool());
        QCOMPARE(settings.values()["bounceHeight"].toInt(), 0);
        QVERIFY(settings.apply({{"bounceEnabled", false}, {"bounceOnLaunch", false},
            {"bounceOnAttention", false}, {"bounceHeight", 24}, {"bounceSpeed", 150}, {"bounceCount", 4}}));
        const auto values = DockSettings(file).values();
        QVERIFY(!values["bounceEnabled"].toBool());
        QVERIFY(!values["bounceOnLaunch"].toBool());
        QVERIFY(!values["bounceOnAttention"].toBool());
        QCOMPARE(values["bounceHeight"].toInt(), 24);
        QCOMPARE(values["bounceSpeed"].toInt(), 150);
        QCOMPARE(values["bounceCount"].toInt(), 4);
        const auto clean = DockSettings::normalized({{"bounceHeight", 1000}, {"bounceSpeed", 0}, {"bounceCount", 99}});
        QCOMPARE(clean["bounceHeight"].toInt(), 64);
        QCOMPARE(clean["bounceSpeed"].toInt(), 50);
        QCOMPARE(clean["bounceCount"].toInt(), 5);
    }
    void behaviorRoundTrip() {
        QTemporaryDir dir; const auto file = dir.filePath("dock.ini");
        DockSettings settings(file);
        QVERIFY(settings.values()["groupApplications"].toBool());
        QVERIFY(!settings.values()["minimizeActive"].toBool());
        QVERIFY(!settings.values()["filterScreen"].toBool());
        QVERIFY(settings.values()["showSeparator"].toBool());
        const QVariantMap changes{{"groupApplications", false}, {"taskSort", 2}, {"groupClick", 1},
            {"middleClick", 3}, {"wheelAction", 1}, {"minimizeActive", true}, {"layoutDirection", 2},
            {"filterScreen", true}, {"filterDesktop", false}, {"filterActivity", false},
            {"onlyMinimized", true}, {"skipMinimized", false}, {"revealAttention", true}, {"showSeparator", false}};
        QVERIFY(settings.apply(changes));
        const auto restored = DockSettings(file).values();
        for (auto it = changes.begin(); it != changes.end(); ++it) QCOMPARE(restored[it.key()], it.value());
        const auto clean = DockSettings::normalized({{"taskSort", 99}, {"middleClick", -1}, {"layoutDirection", "bad"}});
        QCOMPARE(clean["taskSort"].toInt(), 0);
        QCOMPARE(clean["middleClick"].toInt(), 0);
        QCOMPARE(clean["layoutDirection"].toInt(), 0);
    }
    void defaultsAndRoundTrip() {
        QTemporaryDir dir; const auto file = dir.filePath("dock.ini");
        {
            DockSettings settings(file);
            QCOMPARE(settings.values(), DockSettings::defaults());
            QVERIFY(settings.apply({{"edge", 3}, {"spacing", 32}, {"zoom", 2.0}, {"screen", "DP-2"}, {"glow", true}}));
            QVERIFY(settings.saveLaunchers({"applications:org.kde.dolphin.desktop", "applications:org.kde.konsole.desktop"}));
        }
        DockSettings restored(file);
        QCOMPARE(restored.values()["spacing"].toInt(), 32);
        QCOMPARE(restored.values()["edge"].toInt(), 3);
        QCOMPARE(restored.values()["screen"].toString(), "DP-2");
        QCOMPARE(restored.values()["zoom"].toDouble(), 2.0);
        QVERIFY(restored.values()["glow"].toBool());
        const QStringList order{"applications:org.kde.konsole.desktop", "applications:org.kde.dolphin.desktop"};
        QVERIFY(restored.saveLaunchers(order));
        QCOMPARE(DockSettings(file).values()["launchers"].toStringList(), order);
        QVERIFY(restored.saveLaunchers({}));
        QVERIFY(DockSettings(file).values()["launchers"].toStringList().isEmpty());
    }
    void invalidValuesAndUrls() {
        auto v = DockSettings::normalized({{"spacing", -10}, {"iconSize", 999}, {"radius", -1},
            {"zoom", std::numeric_limits<double>::quiet_NaN()}, {"unknown", 42},
            {"launchers", QStringList{"applications:org.kde.dolphin.desktop", "applications:org.kde.dolphin.desktop", "https://example.com/a.desktop", "file:///tmp/My App.desktop"}}});
        QCOMPARE(v["spacing"].toInt(), 0); QCOMPARE(v["iconSize"].toInt(), 96);
        QCOMPARE(v["radius"].toInt(), 0); QCOMPARE(v["zoom"].toDouble(), 1.5);
        QVERIFY(!v.contains("unknown"));
        QCOMPARE(v["launchers"].toStringList().size(), 2);
        QCOMPARE(v["launchers"].toStringList().last(), "file:///tmp/My%20App.desktop");
    }
    void indicatorPersistenceAndValidation() {
        QTemporaryDir dir;
        const auto file = dir.filePath("dock.ini");
        DockSettings settings(file);
        QCOMPARE(settings.values()["indicatorMode"].toInt(), 0);
        QCOMPARE(settings.values()["nativeGroupIndicator"].toInt(), 0);
        QVERIFY(!settings.values()["indicatorUnfocusedColorEnabled"].toBool());
        QVERIFY(settings.values()["revealAnimation"].toBool());
        QVERIFY(settings.apply({{"indicatorMode", 2}, {"indicatorCustomColor", "#ff0000"},
            {"indicatorUnfocusedColor", "#0000ff"}, {"indicatorMaxSegments", 6}, {"revealAnimation", false}}));
        QVERIFY(settings.apply({{"indicatorMode", 0}}));
        DockSettings restored(file);
        QCOMPARE(restored.values()["indicatorCustomColor"].toString(), "#ff0000");
        QCOMPARE(restored.values()["indicatorUnfocusedColor"].toString(), "#0000ff");
        QCOMPARE(restored.values()["indicatorMaxSegments"].toInt(), 6);
        QVERIFY(!restored.values()["revealAnimation"].toBool());
        const auto clean = DockSettings::normalized({{"indicatorMaxSegments", 999},
            {"indicatorCustomColor", "bad-color"}, {"indicatorActiveThickness", -1}, {"indicatorOverflow", true}});
        QCOMPARE(clean["indicatorMaxSegments"].toInt(), 8);
        QCOMPARE(clean["indicatorActiveThickness"].toInt(), 1);
        QCOMPARE(clean["indicatorCustomColor"], DockSettings::defaults()["indicatorCustomColor"]);
        QVERIFY(!clean.contains("indicatorOverflow"));
    }
    void migrateAndSaveCapsuleStyle() {
        QTemporaryDir dir;
        const auto file = dir.filePath("legacy.ini");
        {
            QSettings legacy(file, QSettings::IniFormat);
            legacy.setValue("radius", 19);
            legacy.setValue("borderUseTheme", false);
            legacy.setValue("borderColor", "#112233");
        }
        DockSettings settings(file);
        QCOMPARE(settings.values()["topLeftRadius"].toInt(), 19);
        QCOMPARE(settings.values()["bottomRightRadius"].toInt(), 19);
        QCOMPARE(settings.values()["borderRole"].toString(), "custom");
        QVERIFY(settings.apply({{"backgroundType", 5}, {"bottomRightRadius", -32}, {"borderRole", "highlight"},
            {"gradientTopOpacity", 0.0}, {"gradientBottomOpacity", 0.8}, {"borderOpacity", 0.2}}));
        const auto values = DockSettings(file).values();
        QCOMPARE(values["backgroundType"].toInt(), 5);
        QCOMPARE(values["bottomRightRadius"].toInt(), -32);
        QCOMPARE(values["topLeftRadius"].toInt(), 19);
        QCOMPARE(values["borderRole"].toString(), "highlight");
        QCOMPARE(values["gradientTopOpacity"].toDouble(), 0.0);
        QCOMPARE(values["gradientBottomOpacity"].toDouble(), 0.8);
        QCOMPARE(values["borderOpacity"].toDouble(), 0.2);
    }
    void migrateBackgroundModes() {
        for (int mode = 0; mode <= 5; ++mode) {
            const auto values = DockSettings::normalized({{"backgroundType", mode}, {"backgroundOpacity", 0.42}});
            QCOMPARE(values["backgroundType"].toInt(), mode >= 4 ? mode : 0);
            QCOMPARE(values["systemBlur"].toBool(), mode == 3 || mode == 4);
            QCOMPARE(values["backgroundOpacity"].toDouble(), mode == 1 ? 0.0 : (mode == 2 || mode == 3 ? 0.42 : 1.0));
            QCOMPARE(values["glassOpacity"].toDouble(), 0.42);
            QCOMPARE(DockSettings::normalized(values), values);
        }
    }
    void visibilityAndAlignmentPersistence() {
        QCOMPARE(DockSettings::normalized({{"dodge", false}})["visibilityMode"].toInt(), 3);
        QCOMPARE(DockSettings::normalized({{"dodge", true}})["visibilityMode"].toInt(), 2);
        QTemporaryDir dir;
        const auto file = dir.filePath("dock.ini");
        QVERIFY(DockSettings(file).apply({{"visibilityMode", 0}, {"dockAlignment", 2}, {"alignmentMargin", 64}}));
        const auto restored = DockSettings(file).values();
        QCOMPARE(restored["visibilityMode"].toInt(), 0);
        QCOMPARE(restored["dockAlignment"].toInt(), 2);
        QCOMPARE(restored["alignmentMargin"].toInt(), 64);
    }
    void backgroundPersistence() {
        QTemporaryDir dir; const auto file = dir.filePath("dock.ini");
        DockSettings settings(file);
        QCOMPARE(settings.values()["backgroundType"].toInt(), 0);
        QCOMPARE(settings.values()["radius"].toInt(), 10);
        QVERIFY(settings.apply({{"radius", 0}, {"backgroundType", 4}, {"backgroundOpacity", 0.25},
            {"borderWidth", 0}, {"borderUseTheme", false}, {"borderColor", "#ff0000"},
            {"iconSpacing", 18}, {"horizontalPadding", 30}, {"verticalPadding", 20}}));
        QVERIFY(settings.apply({{"backgroundType", 0}}));
        DockSettings restored(file);
        QCOMPARE(restored.values()["radius"].toInt(), 0);
        QCOMPARE(restored.values()["backgroundOpacity"].toDouble(), 0.25);
        QCOMPARE(restored.values()["borderWidth"].toInt(), 0);
        QCOMPARE(restored.values()["borderColor"].toString(), "#ff0000");
        QVERIFY(!restored.values()["borderUseTheme"].toBool());
        QCOMPARE(restored.values()["iconSpacing"].toInt(), 18);
        QCOMPARE(restored.values()["horizontalPadding"].toInt(), 30);
        QCOMPARE(restored.values()["verticalPadding"].toInt(), 20);
        const auto clean = DockSettings::normalized({{"backgroundType", 900}, {"backgroundOpacity", -1},
            {"borderWidth", 99}, {"borderColor", "bad"}, {"iconSpacing", -9}, {"horizontalPadding", 999},
            {"verticalPadding", std::numeric_limits<double>::quiet_NaN()}, {"blurSaturation", 2.0}});
        QCOMPARE(clean["backgroundType"].toInt(), 0);
        QCOMPARE(clean["backgroundOpacity"].toDouble(), 0.0);
        QCOMPARE(clean["borderWidth"].toInt(), 12);
        QCOMPARE(clean["borderColor"].toString(), "#808080");
        QCOMPARE(clean["iconSpacing"].toInt(), 0);
        QCOMPARE(clean["horizontalPadding"].toInt(), 128);
        QCOMPARE(clean["verticalPadding"].toInt(), 10);
        QVERIFY(!clean.contains("blurSaturation"));
        QVERIFY(!clean.contains("blurContrast"));
        QVERIFY(!clean.contains("blurBrightness"));
    }
    void hoverSettings() {
        QTemporaryDir dir;
        const auto file = dir.filePath("dock.ini");
        DockSettings settings(file);
        QCOMPARE(settings.values()["blastRadius"].toInt(), 2);
        QCOMPARE(settings.values()["hoverLift"].toInt(), 0);
        QVERIFY(settings.apply({{"blastRadius", 4}, {"hoverLift", 6}}));
        DockSettings restored(file);
        QCOMPARE(restored.values()["blastRadius"].toInt(), 4);
        QCOMPARE(restored.values()["hoverLift"].toInt(), 6);
        const auto clean = DockSettings::normalized({{"blastRadius", -1}, {"hoverLift", 999}});
        QCOMPARE(clean["blastRadius"].toInt(), 0);
        QCOMPARE(clean["hoverLift"].toInt(), 64);
    }
    void applicationStatusPersistence() {
        QTemporaryDir dir;
        const auto file = dir.filePath("dock.ini");
        DockSettings settings(file);
        QVariantMap disabled;
        for (const auto *key : {"showWindowPreviews", "highlightPreviewWindow", "showAudioIndicator", "muteOnClick",
                               "showMediaControls", "showBadges", "showProgress"}) {
            QVERIFY(settings.values()[key].toBool());
            disabled[key] = false;
        }
        QVERIFY(settings.apply(disabled));
        DockSettings restored(file);
        for (auto it = disabled.cbegin(); it != disabled.cend(); ++it)
            QVERIFY(!restored.values()[it.key()].toBool());
    }
    void temporarySessionsNeverWrite() {
        QTemporaryDir dir; const auto file = dir.filePath("dock.ini");
        DockSettings settings(file, false);
        QVERIFY(settings.apply({{"spacing", 50}}));
        QVERIFY(!QFile::exists(file));
        DockSettings persistent(file);
        persistent.overrideSession({{"spacing", 40}});
        QVERIFY(!QFile::exists(file));
        QCOMPARE(persistent.values()["spacing"].toInt(), 40);
    }
};
QTEST_GUILESS_MAIN(SettingsTest)
#include "settingstest.moc"
