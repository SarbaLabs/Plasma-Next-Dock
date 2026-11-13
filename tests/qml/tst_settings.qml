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
        spacing.value = 40;
        buttons.applied();
        compare(dockSettings.values.spacing, 40);
        window.close();
        window.openSettings();
        compare(spacing.value, 40);
        window.close();
        dockSettings.apply({spacing: 8});
        window.destroy();
    }
}
