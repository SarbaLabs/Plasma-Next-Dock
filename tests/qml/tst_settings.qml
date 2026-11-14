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
        verify(screen.implicitWidth > 0 && edge.implicitWidth > 0);
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
        findChild(window, "backgroundTypeControl").currentIndex = 4;
        findChild(window, "backgroundOpacityControl").value = 27;
        findChild(window, "borderWidthControl").value = 0;
        findChild(window, "iconSpacingControl").value = 18;
        findChild(window, "horizontalPaddingControl").value = 25;
        findChild(window, "verticalPaddingControl").value = 16;
        window.borderColorValue = "#ff0000";
        findChild(window, "borderUseThemeControl").checked = false;
        findChild(window, "radiusControl").value = 0;
        spacing.value = 40;
        buttons.applied();
        compare(dockSettings.values.spacing, 40);
        compare(dockSettings.values.indicatorMode, 2);
        compare(dockSettings.values.indicatorMaxSegments, 7);
        window.close();
        window.openSettings();
        compare(spacing.value, 40);
        compare(findChild(window, "backgroundTypeControl").currentIndex, 4);
        compare(findChild(window, "backgroundOpacityControl").value, 27);
        compare(findChild(window, "borderWidthControl").value, 0);
        compare(findChild(window, "iconSpacingControl").value, 18);
        compare(findChild(window, "horizontalPaddingControl").value, 25);
        compare(findChild(window, "verticalPaddingControl").value, 16);
        compare(window.borderColorValue, "#ff0000");
        compare(findChild(window, "borderColorControl").enabled, false);
        compare(findChild(window, "blurSaturationControl"), null);
        compare(findChild(window, "radiusControl").value, 0);
        window.close();
        dockSettings.apply({backgroundType: 0, backgroundOpacity: 0.35, borderWidth: 1, borderUseTheme: true, borderColor: "#808080", iconSpacing: 10, horizontalPadding: 12, verticalPadding: 10, radius: 10, spacing: 8, indicatorMode: 0, indicatorMaxSegments: 4});
        window.destroy();
    }
}
