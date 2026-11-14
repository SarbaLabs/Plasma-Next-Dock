// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtTest
TestCase {
    name: "CapsuleBackground"
    when: windowShown
    visible: true
    width: 400; height: 120
    function test_modesAndRadius_data() {
        return [0, 1, 2, 3, 4].map(mode => ({tag: "mode" + mode, mode: mode}));
    }
    function test_modesAndRadius(data) {
        const component = Qt.createComponent("qrc:/qml/CapsuleBackground.qml");
        compare(component.status, Component.Ready, component.errorString());
        const item = component.createObject(this, {width: 300, height: 50, radius: 10,
            backgroundType: data.mode, glowEnabled: true});
        verify(item !== null);
        compare(findChild(item, "solidBackground").visible, data.mode === 0);
        compare(findChild(item, "tintedBackground").visible, data.mode === 2 || data.mode === 3);
        compare(findChild(item, "glassBackground").visible, data.mode === 4);
        const glow = findChild(item, "glowLoader");
        compare(glow.active, data.mode !== 1);
        for (let radius of [0, 5, 10, 100]) {
            item.radius = radius;
            compare(item.effectiveRadius, Math.min(radius, 25));
            compare(findChild(item, "solidBackground").radius, item.effectiveRadius);
            compare(findChild(item, "tintedBackground").radius, item.effectiveRadius);
            if (glow.active) compare(glow.item.cornerRadius, item.effectiveRadius);
        }
        item.glowEnabled = false;
        compare(glow.active, false);
        item.destroy();
    }
}
