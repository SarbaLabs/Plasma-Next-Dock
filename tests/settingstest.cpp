// SPDX-License-Identifier: GPL-2.0-or-later
#include "settings.h"
#include <QTemporaryDir>
#include <QTest>
#include <limits>
class SettingsTest : public QObject
{
    Q_OBJECT
private Q_SLOTS:
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
