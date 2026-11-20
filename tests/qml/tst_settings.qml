// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtTest
TestCase {
    name: "SettingsInterface"
    when: windowShown
    function test_applyAndDiscard() {
        const component = Qt.createComponent("qrc:/qml/Settings.qml");
        compare(component.status, Component.Ready, component.errorString());
        const window = component.createObject(this);
        verify(window !== null);
        window.openSettings();
        const screen = findChild(window, "screenControl");
        const edge = findChild(window, "edgeControl");
        const alignment = findChild(window, "dockAlignmentControl");
        const visibility = findChild(window, "visibilityModeControl");
        compare(alignment.currentIndex, 1);
        alignment.currentIndex = 2;
        edge.currentIndex = 2;
        compare(alignment.textAt(2), i18n("Bottom"));
        compare(alignment.currentIndex, 2);
        edge.currentIndex = 0;
        compare(alignment.textAt(2), i18n("Right"));
        visibility.currentIndex = 0;
        verify(screen.implicitWidth > 0 && edge.implicitWidth > 0);
        verify(screen.textAt(1).includes("DP-1") && screen.textAt(1).includes("AOC 2590G4"));
        verify(screen.textAt(2).startsWith("DP-2") && screen.textAt(2).endsWith("…"));
        compare(screen.textAt(3), "HDMI-1");
        screen.activated(2);
        compare(window.draftScreen, "DP-2");
        screen.activated(0);
        const preferred = screen.implicitWidth;
        window.width = 800;
        wait(0);
        compare(screen.implicitWidth, preferred);
        window.width = 460;
        wait(0);
        compare(screen.implicitWidth, preferred);
        const spacing = findChild(window, "spacingControl");
        const buttons = findChild(window, "settingsButtons");
        verify(spacing !== null && buttons !== null);
        spacing.value = 30;
        window.close();
        compare(dockSettings.values.spacing, 8); // Close does not apply draft edits.
        window.openSettings();
        compare(spacing.value, 8);
        const indicators = findChild(window, "indicatorsSettings");
        verify(indicators !== null);
        indicators.cfg_indicatorMode = 2;
        indicators.cfg_indicatorMaxSegments = 7;
        findChild(window, "backgroundTypeControl").currentIndex = 1;
        findChild(window, "glassOpacityControl").value = 27;
        findChild(window, "borderWidthControl").value = 0;
        findChild(window, "iconSpacingControl").value = 18;
        findChild(window, "horizontalPaddingControl").value = 25;
        findChild(window, "verticalPaddingControl").value = 16;
        findChild(window, "outlineColorControl").fixedColor = "#ff0000";
        findChild(window, "outlineColorControl").role = "custom";
        findChild(window, "topLeftControl").value = 0;
        findChild(window, "blastRadiusControl").value = 4;
        findChild(window, "hoverLiftControl").value = 6;
        for (const name of ["windowPreviews", "highlightPreview", "audioIndicator", "muteOnClick", "mediaControls", "badges", "progress"])
            findChild(window, name + "Control").checked = false;
        const behavior = findChild(window, "behaviorSettings");
        verify(behavior !== null);
        behavior.change("layoutDirection", 2);
        behavior.change("minimizeActive", true);
        behavior.change("bounceHeight", 22);
        behavior.change("bounceOnLaunch", false);
        // Applying a stale settings draft must not overwrite newly pinned apps.
        dockSettings.saveLaunchers([testLauncherUrls[0]]);
        findChild(window, "glowControl").checked = true;
        findChild(window, "glowRadiusControl").value = 116;
        findChild(window, "glowIntensityControl").value = 150;
        findChild(window, "glowOpacityControl").value = 65;
        findChild(window, "iconColorsControl").currentIndex = 1;
        findChild(window, "tintIconsControl").checked = true;
        findChild(window, "iconTintControl").role = "custom";
        findChild(window, "iconTintControl").fixedColor = "#e83a65";
        findChild(window, "iconTintSaturationControl").value = 72;
        spacing.value = 40;
        buttons.applied();
        compare(dockSettings.values.spacing, 40);
        compare(dockSettings.values.layoutDirection, 2);
        compare(dockSettings.values.minimizeActive, true);
        compare(dockSettings.values.bounceHeight, 22);
        compare(dockSettings.values.bounceOnLaunch, false);
        compare(dockSettings.values.launchers, [testLauncherUrls[0]]);
        compare(dockSettings.values.indicatorMode, 2);
        compare(dockSettings.values.indicatorMaxSegments, 7);
        window.close();
        window.openSettings();
        compare(findChild(window, "iconColorsControl").currentIndex, 1);
        compare(findChild(window, "tintIconsControl").checked, true);
        compare(findChild(window, "iconTintControl").role, "custom");
        compare(findChild(window, "iconTintControl").fixedColor, "#e83a65");
        compare(findChild(window, "iconTintSaturationControl").value, 72);
        compare(spacing.value, 40);
        compare(findChild(window, "glowRadiusControl").value, 116);
        compare(findChild(window, "glowIntensityControl").value, 150);
        compare(findChild(window, "glowOpacityControl").value, 65);
        for (const name of ["windowPreviews", "highlightPreview", "audioIndicator", "muteOnClick", "mediaControls", "badges", "progress"])
            compare(findChild(window, name + "Control").checked, false);
        compare(findChild(window, "blastRadiusControl").value, 4);
        compare(findChild(window, "hoverLiftControl").value, 6);
        compare(findChild(window, "backgroundTypeControl").currentIndex, 1);
        compare(findChild(window, "glassOpacityControl").value, 27);
        compare(findChild(window, "borderWidthControl").value, 0);
        compare(findChild(window, "iconSpacingControl").value, 18);
        compare(findChild(window, "horizontalPaddingControl").value, 25);
        compare(findChild(window, "verticalPaddingControl").value, 16);
        compare(findChild(window, "outlineColorControl").fixedColor, "#ff0000");
        compare(findChild(window, "outlineColorControl").enabled, false);
        compare(findChild(window, "blurSaturationControl"), null);
        compare(findChild(window, "topLeftControl").value, 0);
        findChild(window, "backgroundTypeControl").currentIndex = 2;
        verify(!findChild(window, "backgroundOpacityControl").visible);
        verify(findChild(window, "upperColorControl").visible);
        findChild(window, "upperColorControl").role = "highlight";
        findChild(window, "lowerColorControl").role = "custom";
        findChild(window, "lowerColorControl").fixedColor = "#123456";
        findChild(window, "bottomLeftControl").value = -22;
        findChild(window, "topOpacityControl").value = 0;
        findChild(window, "bottomOpacityControl").value = 75;
        findChild(window, "gradientMidpointControl").value = 72;
        findChild(window, "systemBlurControl").checked = true;
        buttons.applied();
        compare(dockSettings.values.gradientMidpoint, 72);
        compare(dockSettings.values.systemBlur, true);
        compare(dockSettings.values.gradientTopRole, "highlight");
        compare(dockSettings.values.gradientBottomColor, "#123456");
        compare(dockSettings.values.gradientTopOpacity, 0);
        compare(dockSettings.values.gradientBottomOpacity, 0.75);
        compare(dockSettings.values.bottomLeftRadius, -22);
        window.close();
        dockSettings.apply({grayscaleIcons: false, tintIcons: false, iconTintRole: "highlight", iconTintColor: "#3daee9", iconTintSaturation: 100, glow: false, glowRadius: 0, glowIntensity: 100, glowOpacity: 30, bounceHeight: 0, bounceOnLaunch: true, launchers: [], layoutDirection: 0, minimizeActive: false, showWindowPreviews: true, highlightPreviewWindow: true, showAudioIndicator: true, muteOnClick: true, showMediaControls: true, showBadges: true, showProgress: true, blastRadius: 2, hoverLift: 0, backgroundType: 0, backgroundOpacity: 0.35, borderWidth: 1, borderUseTheme: true, borderColor: "#808080", iconSpacing: 10, horizontalPadding: 12, verticalPadding: 10, radius: 10, spacing: 8, indicatorMode: 0, indicatorMaxSegments: 4});
        window.destroy();
    }
}
