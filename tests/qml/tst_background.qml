// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtTest
TestCase {
    name: "CapsuleBackground"
    when: windowShown
    visible: true
    width: 400; height: 120
    function test_modesAndRadius_data() {
        return [0, 4, 5].map(mode => ({tag: "mode" + mode, mode: mode}));
    }
    function test_modesAndRadius(data) {
        const component = Qt.createComponent("qrc:/qml/CapsuleBackground.qml");
        compare(component.status, Component.Ready, component.errorString());
        const item = component.createObject(this, {width: 300, height: 50, corners: [0, 10, -10, -20],
            backgroundType: data.mode, glowEnabled: true});
        verify(item !== null);
        compare(item.fillShape.visible, true);
        const ends = [[0,0,0,50], [0,50,0,0], [300,0,0,0], [0,0,300,0]];
        for (let edge = 0; edge < 4; ++edge) {
            item.edge = edge;
            compare([item.desktopSide.x, item.desktopSide.y, item.screenSide.x, item.screenSide.y], ends[edge]);
        }
        verify(item.drawing.fill.length > 0);
        verify(item.drawing.outline.length > 0);
        const glow = findChild(item, "glowLoader");
        compare(glow.active, true);
        if (glow.active) compare(glow.item.silhouette, item.drawing.fill);
        item.customBorderWidth = 0;
        compare(item.drawing.outline, "");
        item.destroy();
    }
}
